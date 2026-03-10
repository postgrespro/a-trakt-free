#!/usr/bin/perl

# Скрипт позволяющий запустить исслкдуемую программу с заданной целью и с заданным сэмплом
# ориентируясь на afl_runner.conf от существующей цели. Оный конфиг определяет И.П. и цель
# а сампл может быть или указан в качестве второго аргумента, или его скрипт сгенерирует сам

use strict;
use utf8;
use Getopt::Long qw(GetOptions);
use String::ShellQuote;
use Path::Tiny;
use JSON;

my $runner_conf = $ARGV[0];

die "Укажите конфигурациионный файл afl_runner первым аргументом" unless $runner_conf;

my $sample_file = $ARGV[1];

if (! $sample_file)
{
  $sample_file = Path::Tiny->tempfile();
  print "Используем случайные данные в качестве сэипла: '$sample_file'\n";
  `dd if=/dev/random of=$sample_file count=1`;
}

my $h = JSON->new->decode(path($runner_conf)->slurp);

my $command = $h->{command},
my $storage_init_command = $h->{storage_init};
my $env = $h->{env};

# Подменяем макрос @@ в комманде фаззера на конкретное имя файла
$command =~ s/\@\@/$sample_file/g;
# И включаем печать отладочных символов. Нам тут они нужны
$env->{ASAN_OPTIONS} =~ s/symbolize=0/symbolize=1/;

my $instance_name = 'single_run';

if($storage_init_command)
{
  my $cmd = $storage_init_command;
  $cmd =~ s/\@INSTANCE_NAME\@/$instance_name/g;
  print "Initializing storage for '$instance_name': $cmd \n";
  system($cmd);
}


my $env_str = "";
foreach my $key (keys %$env)
{
  $env_str .= " " if $env_str;
  my $value = $env->{$key};
  $value =~ s/\@INSTANCE_NAME\@/$instance_name/g;
  $env_str .= $key."=".shell_quote($value);
}

my $command_to_run = "$env_str $command";

print "Running `$command_to_run`\n";
`$command_to_run`;
exit(0);



