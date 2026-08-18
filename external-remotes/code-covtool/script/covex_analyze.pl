#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use CovEx::Config;
use CovEx::Analyzer;

# Парсинг конфигурации
my $config = CovEx::Config->new();
$config->parse_command_line();

# Запускаем анализатор
my $analyzer = CovEx::Analyzer->new($config);
$analyzer->run();

exit 0;

__END__

=encoding utf8

=head1 NAME

covex_analyze.pl - Анализирует эволюции формата LCOV файлов

=head1 SYNOPSIS

covex_analyze.pl --project /path/to/src [--include /path/to/include] [options]

=head1 OPTIONS

=over 4

=item B<--project>, B<-p> I<path>

Путь к исходным файлам C/C++ проекта. По умолчанию: ./t/samples/src

=item B<--include>, B<-i> I<path>

Путь к заголовочным файлам. По умолчанию: ./t/samples/include

=item B<--start>, B<-s> I<version>

Начальная версия для анализа. По умолчанию: 1.16

=item B<--work-dir>, B<-w> I<path>

Рабочий каталог. По умолчанию: lcov_analysis

=item B<--output>, B<-o> I<file>

Файл для сохранения результатов JSON

=item B<--verbose>, B<-v>

Подробный вывод

=item B<--keep-repo>, B<-k>

Не удалять клон репозитория LCOV после завершения работы

=item B<--skip-errors>

Пропускать версии с ошибками сборки вместо остановки анализа

=item B<--help>, B<-h>

Вывод этой справки

=back

=head1 DESCRIPTION

Утилита анализирует изменения формата lcov-файлов между разными версиями LCOV.
Для каждой версии LCOV (начиная с указанной) копирует тестовый проект, собирает
его с покрытием, генерирует lcov-файл и сравнивает его с предыдущей версией.

=head1 ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ

=over 4

=item Базовый анализ с настройками по умолчанию:

    ./covex_analyze.pl

=item Анализ конкретного проекта:

    ./covex_analyze.pl --project ~/my_project/src --include ~/my_project/include

=item Сохранение результатов в файл:

    ./covex_analyze.pl --output results.json --verbose

=item Анализ с определенной версии:

    ./covex_analyze.pl --start 1.14 --skip-errors

=back

=head1 ВЫХОДНЫЕ ДАННЫЕ

Программа генерирует JSON файл с результатами анализа, содержащий:

=over 4

=item * Список проанализированных версий

=item * Различия в формате lcov-файлов между версиями

=item * Статистику изменений

=back

=cut
