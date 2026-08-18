#include "../include/sample_functions.h"

// Для checksum тестов (будем модифицировать)
int calculate_score(int a, int b) {
    int result = a * 2 + b * 3;   // DA:1 - меняем для checksum
    if (result > 100) return 100; // BRDA:2,0,0
    if (result < 0) return 0;     // BRDA:3,0,0
    return result;                // DA:4
}

// Сложные ветвления
char* analyze_number(int num) {
    if (num % 2 == 0) {           // BRDA:1,0,0
        return "even";            // DA:2
    } else {                      // BRDA:1,0,1
        if (num % 3 == 0) {       // BRDA:2,0,0
            return "odd3";        // DA:3
        }
        return "odd";             // DA:4
    }
}
