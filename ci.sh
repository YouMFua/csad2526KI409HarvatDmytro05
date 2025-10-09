#!/usr/bin/env bash
set -e  # stop on error

echo "=== Preparing build environment ==="
# Always work from a clean temp copy so the build is isolated
WORKDIR=/tmp/project_build_$$
mkdir -p "$WORKDIR"
echo "Copying sources to $WORKDIR ..."
cp -r . "$WORKDIR"
cd "$WORKDIR"

echo "=== Cleaning previous build ==="
rm -rf build

echo "=== Creating build directory ==="
mkdir -p build
cd build

echo "=== Detecting platform and configuring ==="
case "$(uname -s)" in
  Linux*)   cmake -G "Ninja" -DCMAKE_BUILD_TYPE=Release .. ;;
  Darwin*)  cmake -G "Ninja" -DCMAKE_BUILD_TYPE=Release .. ;;
  MINGW*|MSYS*|CYGWIN*) cmake -G "Ninja" -A x64 -DCMAKE_BUILD_TYPE=Release .. ;;
  *) echo "Unknown OS"; exit 1 ;;
esac

echo "=== Building project ==="
cmake --build . --config Release

echo "=== Running tests ==="
ctest --output-on-failure

echo "=== Build and test complete ==="
