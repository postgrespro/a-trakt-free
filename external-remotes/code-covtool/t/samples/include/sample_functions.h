#ifndef SAMPLE_FUNCTIONS_H
#define SAMPLE_FUNCTIONS_H

// Базовые функции (line coverage)
int simple_math(int a, int b);
float safe_divide(int a, int b);

// Функции с условиями (branch coverage)  
int check_value(int value);
int find_max(int a, int b, int c);

// Функции с циклами (loop coverage)
int calculate_sum(int n);
void print_numbers(int n);

// Специальные функции (edge cases)
int calculate_score(int a, int b); // Для checksum тестов
char* analyze_number(int num);     // Для сложных ветвлений

#endif
