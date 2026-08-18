#include "../include/sample_functions.h"
#include <stdio.h>

int main() {
    printf("Math1: %d\n", simple_math(3, 1));
    printf("Math2: %d\n", simple_math(5, 2));
    printf("Div1: %.2f\n", safe_divide(10, 2));
    printf("Div2: %.2f\n", safe_divide(7, 0));
    return 0;
}
