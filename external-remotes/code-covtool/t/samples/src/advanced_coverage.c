#include "../include/sample_functions.h"
#include <stdio.h>

// Условные операции
int check_value(int value) {
    if (value > 100) return 3;  // BRDA:1,0,0
    if (value > 50) return 2;   // BRDA:1,0,1  
    if (value > 0) return 1;    // BRDA:1,0,2
    return 0;                   // BRDA:1,0,3
}

int find_max(int a, int b, int c) {
    int max = a;               // DA:1
    if (b > max) max = b;      // BRDA:2,0,0
    if (c > max) max = c;      // BRDA:3,0,0
    return max;                // DA:4
}

// Функции с циклами
int calculate_sum(int n) {
    int sum = 0;                    // DA:1
    for (int i = 1; i <= n; i++) {  // DA:2 (инициализация)
        sum += i;                   // DA:3 × n раз
    }
    return sum;                     // DA:4
}

void print_numbers(int n) {
    for (int i = 0; i < n; i++) {  // DA:1
        if (i % 2 == 0) {          // BRDA:2,0,0
            printf("E ");          // DA:3 для четных
        } else {
            printf("O ");          // DA:4 для нечетных
        }
    }
    printf("\n");                  // DA:5
}
