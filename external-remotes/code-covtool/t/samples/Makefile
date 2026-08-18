CC = gcc
CFLAGS = -Wall -Wextra -fprofile-arcs -ftest-coverage -I./include
BUILD_DIR = build
COVERAGE_DIR = coverage

.PHONY: clean coverage

coverage:
	@echo "Generating coverage files..."
	perl scripts/generate_coverage.pl
	@echo "Coverage files ready in $(COVERAGE_DIR)/"

clean:
	@echo "Cleaning generated files..."
	rm -rf $(BUILD_DIR)
	find . -name "*.gcda" -o -name "*.gcno" -o -name "*.gcov" | xargs rm -f
	@echo "Clean complete"
