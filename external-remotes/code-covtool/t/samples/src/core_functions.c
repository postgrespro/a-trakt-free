#include "../include/sample_functions.h"

// Базовые математические операции
int simple_math(int a, int b) {
    return a + b - a * b;  // DA:1 - комбинированная операция
}

float safe_divide(int a, int b) {
    if (b == 0) return 0.0f;  // BRDA:2,0,0 - ветвление
    return (float)a / b;      // DA:3
}
