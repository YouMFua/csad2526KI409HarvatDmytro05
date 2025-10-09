@echo off
echo === Cleaning previous build ===
rmdir /s /q build

echo === Creating build directory ===
mkdir build
cd build

echo === Configuring project with MinGW ===
cmake -G "MinGW Makefiles" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ ..

if %errorlevel% neq 0 (
    echo [ERROR] CMake configuration failed.
    pause
    exit /b %errorlevel%
)

echo === Building project ===
mingw32-make

if %errorlevel% neq 0 (
    echo [ERROR] Build failed.
    pause
    exit /b %errorlevel%
)

echo === Running tests ===
ctest --output-on-failure

cd ..
echo === Build and test complete ===
pause
