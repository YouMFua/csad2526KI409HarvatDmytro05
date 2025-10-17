cmake_minimum_required(VERSION 3.10)

project(csad2526KI409HarvatDmytro05)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Main executable
add_executable(${PROJECT_NAME} main.cpp math_operations.cpp)

# Enable testing
enable_testing()

# GoogleTest
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/heads/main.zip
)
# For Windows: Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

# Test executable
add_executable(unit_tests tests/unit_tests.cpp math_operations.cpp)
target_link_libraries(unit_tests gtest_main)

# Add test
add_test(NAME MathOperationsTests COMMAND unit_tests)