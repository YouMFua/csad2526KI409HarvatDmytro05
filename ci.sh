#!/usr/bin/env bash
set -e  # зупинятись при помилках

echo "=== Cleaning previous build ==="
rm -rf build

echo "=== Creating build directory ==="
mkdir -p build
cd build

echo "=== Configuring project with MinGW / GCC ==="
cmake -G "MinGW Makefiles" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ ..

echo "=== Building project ==="
mingw32-make

echo "=== Running tests ==="
ctest --output-on-failure

cd ..
echo "=== Build and test complete ==="
