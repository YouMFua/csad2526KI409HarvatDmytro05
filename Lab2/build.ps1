param(
  [string]$BuildRoot = "build",
  [string]$SourceDir = "."   # current folder only
)

$ErrorActionPreference = "Stop"

function Ensure-Dir($path) {
  New-Item -ItemType Directory -Force -Path $path | Out-Null
}

# ---- Locate GHDL ------------------------------------------------------------
$ghdlCmd = Get-Command ghdl -ErrorAction SilentlyContinue
if ($ghdlCmd) {
  $ghdl = $ghdlCmd.Path
} else {
  $candidates = @(
    "C:\GHDL\bin\ghdl.exe",
    "C:\Program Files\GHDL\bin\ghdl.exe",
    "C:\Program Files (x86)\GHDL\bin\ghdl.exe"
  )
  $ghdl = $null
  foreach ($c in $candidates) { if (Test-Path $c) { $ghdl = $c; break } }
  if (-not $ghdl) { throw "ghdl.exe not found. Add it to PATH or update candidate paths in this script." }
}
Write-Host ("Using GHDL: {0}" -f $ghdl)

# ---- Clean build root -------------------------------------------------------
if (Test-Path $BuildRoot) { Remove-Item -Recurse -Force $BuildRoot }
Ensure-Dir $BuildRoot

# ---- Collect VHDL files (single directory only) ----------------------------
$searchPath = Join-Path $SourceDir "*"
$allFiles = Get-ChildItem -Path $searchPath -File -Include *.vhd, *.vhdl -ErrorAction SilentlyContinue
if (-not $allFiles -or $allFiles.Count -eq 0) {
  Write-Host ("No .vhd or .vhdl files found in {0}" -f (Resolve-Path $SourceDir).Path)
  exit 0
}

# Heuristics for testbench names
function Is-Testbench([IO.FileInfo]$f) {
  return ($f.Name -match '(_tb|_testbench)\.vhd(l)?$') -or ($f.BaseName -match '^(tb_|testbench_)')
}

$designFiles = @()
$tbFiles     = @()
foreach ($f in $allFiles) {
  if (Is-Testbench $f) { $tbFiles += $f } else { $designFiles += $f }
}

# ---- Helper: analyze one file into a given workdir -------------------------
function Analyze-File($file, $workDir, $logPath) {
  Ensure-Dir $workDir
  Ensure-Dir (Split-Path -Parent $logPath)
  & $ghdl -a --std=08 --workdir="$workDir" $file.FullName *>&1 | Tee-Object -FilePath $logPath | Out-Null
  return ($LASTEXITCODE -eq 0)
}

# ---- Helper: extract first entity name from a file --------------------------
function First-Entity($file) {
  $content = Get-Content -Raw $file.FullName
  $rxOpts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor `
            [System.Text.RegularExpressions.RegexOptions]::Multiline
  $pattern = '^\s*entity\s+([A-Za-z0-9_]+)\s+is'
  $m = [System.Text.RegularExpressions.Regex]::Match($content, $pattern, $rxOpts)
  if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}

# ---- Step 1: compile EACH DESIGN file into its OWN work --------------------
foreach ($f in $designFiles) {
  $name   = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
  $outdir = Join-Path $BuildRoot $name
  $work   = Join-Path $outdir "work"
  $logs   = Join-Path $outdir "logs"
  $waves  = Join-Path $outdir "waves"

  Ensure-Dir $outdir; Ensure-Dir $logs; Ensure-Dir $waves

  Write-Host ("[Per-file] Analyzing: {0} -> {1}" -f $f.Name, $work)
  $ok = Analyze-File -file $f -workDir $work -logPath (Join-Path $logs "analyze.log")
  if (-not $ok) {
    Write-Warning ("Analyze failed for {0} (see {1})." -f $f.Name, (Join-Path $logs "analyze.log"))
    continue
  }

  $entity = First-Entity $f
  if ($entity) {
    Write-Host ("[Per-file] Elaborating: {0}" -f $entity)
    & $ghdl -e --std=08 --workdir="$work" $entity *>&1 | Tee-Object -FilePath (Join-Path $logs "elaborate.log") | Out-Null
    # (Not running design entities)
  }
}

# ---- Step 2: for EACH TESTBENCH, compile deps into TB's own work ----------
foreach ($tb in $tbFiles) {
  $tbName = [System.IO.Path]::GetFileNameWithoutExtension($tb.Name)
  $tbDir  = Join-Path $BuildRoot $tbName
  $tbWork = Join-Path $tbDir "work"
  $tbLogs = Join-Path $tbDir "logs"
  $tbWaves= Join-Path $tbDir "waves"
  Ensure-Dir $tbDir; Ensure-Dir $tbLogs; Ensure-Dir $tbWaves

  Write-Host ("[TB] Preparing isolated work for: {0}" -f $tb.Name)

  # 2a) compile ALL design files into TB's work
  foreach ($df in $designFiles) {
    Write-Host ("[TB] Analyzing dependency: {0}" -f $df.Name)
    $ok = Analyze-File -file $df -workDir $tbWork -logPath (Join-Path $tbLogs "analyze_dep_$($df.BaseName).log")
    if (-not $ok) {
      Write-Warning ("Dependency analyze failed: {0} (see logs)" -f $df.Name)
      continue
    }
  }

  # 2b) compile the TB itself into the SAME TB work
  Write-Host ("[TB] Analyzing testbench: {0}" -f $tb.Name)
  $okTb = Analyze-File -file $tb -workDir $tbWork -logPath (Join-Path $tbLogs "analyze_tb.log")
  if (-not $okTb) {
    Write-Warning ("Testbench analyze failed: {0}" -f $tb.Name)
    continue
  }

  # 2c) elaborate & run TB
  $tbEntity = First-Entity $tb
  if (-not $tbEntity) {
    Write-Warning ("No entity found in TB file: {0}" -f $tb.Name)
    continue
  }

  Write-Host ("[TB] Elaborating: {0}" -f $tbEntity)
  & $ghdl -e --std=08 --workdir="$tbWork" $tbEntity *>&1 | Tee-Object -FilePath (Join-Path $tbLogs "elaborate_tb.log") | Out-Null
  $okElab = ($LASTEXITCODE -eq 0)
  if (-not $okElab) {
    Write-Warning ("TB elaboration failed: {0}" -f $tbEntity)
    continue
  }

  Write-Host ("[TB] Running: {0}" -f $tbEntity)
  $vcdOut = Join-Path $tbWaves ("{0}.vcd" -f $tbEntity)
  & $ghdl -r --std=08 --workdir="$tbWork" $tbEntity --vcd="$vcdOut" *>&1 | Tee-Object -FilePath (Join-Path $tbLogs "run_tb.log") | Out-Null
  Write-Host ("[TB] Waveform: {0}" -f $vcdOut)
}

Write-Host ("Done. Artifacts are under: {0}\<name>\{{1}}" -f $BuildRoot, "work,logs,waves")
