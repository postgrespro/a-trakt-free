#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/020_command_executor_role";
use Path::Tiny;

use Test::More tests => 12;

# Проверяем роль на тестовом тракте

use lib $FindBin::Bin."/../lib";

use Trakt;

my $branch_name = 'none';

my $trakt_name = "020_command_executor_role/020_trakt";

my $tmp_dir = path($FindBin::Bin."/tmp");
$tmp_dir->remove_tree if $tmp_dir->exists;

my $tmpl = "/tmp/020_command_executor_role/020_trakt.none.";

my $cache_tmpl = $tmpl."cache/step1";
my $exch_tmpl = $tmpl."exch/step1";

my $target_cache_dir = path($FindBin::Bin.$cache_tmpl."/target1");
my $target_exchange_dir = path($FindBin::Bin.$exch_tmpl."/target1");

my $step_cache_dir = path($FindBin::Bin.$cache_tmpl);
my $step_exchange_dir = path($FindBin::Bin.$exch_tmpl);

my $trakt_cache_dir = path($FindBin::Bin.$tmpl."cache");
my $trakt_exchange_dir = path($FindBin::Bin.$tmpl."exch");

my $trakt = Trakt->create(name => $trakt_name, branch => $branch_name);
$trakt->work_dir($tmp_dir); # Устанавливаем временную директорию как рабочую директорию тракта...

$trakt->run_command('trakt', "echo Тракт создан и готов к работе");

select(STDERR); # перенаправляем стандартый вывод на STDERR чтобы не мешал тестированию
$trakt->run();
select(STDOUT); #возвращаем стандарный вывод на место и приступаем к тестированию...

my $command_log_file = 'commands.log';
my $command_json_file = '/reports/commands.json';

sub strip_log_file
{
    my $lf = shift;
    my $tail = shift;

    my $pt1 = $FindBin::Bin."/tmp/020_command_executor_role/020_trakt.none.cache";
    my $pt2 = "";
    $pt1 = $pt1.$tail;

    $$lf =~ s/$pt1/$pt2/g;

    $$lf =~ s/\..{8}//g;
}

# Test1.
ok($target_cache_dir->child($command_log_file)->exists, 'Проверяем, что лог файл для цели target1 шага step1 пишется в правильное место.');

# Test2.
ok($step_cache_dir->child($command_log_file)->exists, 'Проверяем, что лог файл для шага step1 пишется в правильное место.');

# Test3.
ok($trakt_cache_dir->child($command_log_file)->exists, 'Проверяем, что лог файл для тракта пишется в правильное место.');

my $log_file = $target_cache_dir->child($command_log_file)->slurp;

my $log_file_expected = path($FindBin::Bin.'/020_command_executor_role/target1.log.expected')->slurp;

strip_log_file(\$log_file, '/step1/target1/');

# Test4.
is($log_file, $log_file_expected, 'содержание лог файла цели target1 шага step1 правильное');

$log_file = $step_cache_dir->child($command_log_file)->slurp;

$log_file_expected = path($FindBin::Bin.'/020_command_executor_role/step1.log.expected')->slurp;

strip_log_file(\$log_file, '/step1/');

# Test5.
is($log_file, $log_file_expected, 'содержание лог файла шага step1 правильное');

$log_file = $trakt_cache_dir->child($command_log_file)->slurp;

$log_file_expected = path($FindBin::Bin.'/020_command_executor_role/trakt.log.expected')->slurp;

strip_log_file(\$log_file, '/');

# Test6.
is($log_file, $log_file_expected, 'содержание лог файла тракта правильное');

my $target_json_file = path($target_exchange_dir.$command_json_file);

# Test7.
ok($target_json_file->exists, 'Проверяем, что json файл для цели target1 шага step1 пишется в правильное место.');

my $step_json_file = path($step_exchange_dir.$command_json_file);

# Test8.
ok($step_json_file->exists, 'Проверяем, что json файл для шага step1 пишется в правильное место.');

my $trakt_json_file = path($trakt_exchange_dir.$command_json_file);

# Test9.
ok($trakt_json_file->exists, 'Проверяем, что json файл для тракта пишется в правильное место.');

my $test_json = JSON->new->decode($target_json_file->slurp);

# Test10.
is($test_json->{tag1}, "echo Работает цель 'target1'\t шага 'step1'\n", 'Проверка содержания json файла для цели target1 шага step1.');

$test_json = JSON->new->decode($step_json_file->slurp);

# Test11.
is($test_json->{step1}, "echo Работает шаг 'step1'\n", 'Проверка содержания json файла для шага step1.');

$test_json = JSON->new->decode($trakt_json_file->slurp);

# Test12.
is($test_json->{trakt}, "echo Тракт создан и готов к работе\n", 'Проверка содержания json файлаа для тракта.');

$tmp_dir->remove_tree;

