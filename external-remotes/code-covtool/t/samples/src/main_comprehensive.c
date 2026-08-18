#include "../include/sample_functions.h"
#include <stdio.h>

int main() {
    // Полное покрытие всех функций
    printf("Math: %d, %.1f\n", simple_math(2, 3), safe_divide(10, 2));
    
    // Все ветви check_value
    printf("Values: %d,%d,%d,%d\n", 
           check_value(-5), check_value(25), check_value(75), check_value(150));
    
    // Max function
    printf("Max: %d\n", find_max(3, 1, 2));
    
    // Циклы
    printf("Sum: %d\n", calculate_sum(5));
    print_numbers(4);

    return 0;
}
