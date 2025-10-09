#include <gtest/gtest.h>
#include "../math_operations.h"

TEST(MathOperationsTest, AddPositiveNumbers) {
    EXPECT_EQ(add(2, 3), 5);
}

TEST(MathOperationsTest, AddNegativeNumbers) {
    EXPECT_EQ(add(-2, -3), -5);
}

TEST(MathOperationsTest, AddPositiveAndNegative) {
    EXPECT_EQ(add(5, -3), 2);
}

TEST(MathOperationsTest, AddZero) {
    EXPECT_EQ(add(0, 0), 0);
    EXPECT_EQ(add(0, 5), 5);
    EXPECT_EQ(add(5, 0), 5);
}