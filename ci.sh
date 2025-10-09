#!/usr/bin/env bash
set -e  # зупинятись при помилках

cd /tmp
cp -r /mnt/c/csad2526KI409HarvatDmytro05 ./project
cd project

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

cd ..
echo "=== Build and test complete ==="
