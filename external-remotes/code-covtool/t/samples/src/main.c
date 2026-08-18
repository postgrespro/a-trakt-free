#include "../include/sample_functions.h"
#include <stdio.h>

void cover_check_value(void) {
    // Исполняем все 4 ветви: возвраты 0, 1, 2, 3
    check_value(-5);   // → 0
    check_value(1);    // → 1  
    check_value(51);   // → 2
    check_value(101);  // → 3  
    // Граничные значения
    check_value(0);    // → 0
    check_value(50);   // → 1
    check_value(100);  // → 2
}

void cover_find_max(void) {
    // Покрываем все комбинации условий if
    find_max(1, 2, 3);  // b > a, c > b
    find_max(3, 2, 1);  // b < a, c < b  
    find_max(2, 3, 1);  // b > a, c < b
    find_max(2, 1, 3);  // b < a, c > b
    find_max(5, 5, 5);  // все равны
}

void cover_calculate_sum(void) {
    // Циклы разной длины
    calculate_sum(0);   // цикл не выполняется
    calculate_sum(1);   // 1 итерация
    calculate_sum(5);   // 5 итераций
}

void cover_print_numbers(void) {
    // Цикл + ветвление внутри
    print_numbers(0);   // нет вывода
    print_numbers(1);   // "E " (четное)
    print_numbers(2);   // "E O " (четное + нечетное)
}

void cover_simple_math(void) {
    // Просто исполняем
    simple_math(2, 3);
    simple_math(0, 0);
    simple_math(-5, 5);
}

void cover_safe_divide(void) {
    // Обе ветви: b == 0 и b != 0
    safe_divide(10, 2);   // b != 0
    safe_divide(5, 0);    // b == 0
    safe_divide(0, 0);    // b == 0
}

void cover_calculate_score(void) {
    // Все три ветви: result > 100, result < 0, else
    calculate_score(20, 20);  // 100 (== 100)
    calculate_score(60, 0);   // 120 (> 100) → 100
    calculate_score(-10, -10);// -50 (< 0) → 0
    calculate_score(10, 10);  // 50 (между 0 и 100)
}

void cover_analyze_number(void) {
    // Все три возвращаемых значения
    analyze_number(2);   // "even"
    analyze_number(3);   // "odd3"  
    analyze_number(5);   // "odd"
    analyze_number(0);   // "even" (0 % 2 == 0)
    analyze_number(-3);  // "odd3"
}

int main(void) {
    printf("=== Запуск для покрытия кода (coverage) ===\n\n");
    
    cover_check_value();
    cover_find_max();
    cover_calculate_sum();
    cover_print_numbers();
    cover_simple_math();
    cover_safe_divide();
    cover_calculate_score();
    cover_analyze_number();
    
    printf("\nВсе функции исполнены. Можно измерять coverage.\n");
    return 0;
}