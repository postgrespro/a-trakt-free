#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/../lib";
use Data::Dumper;

use Path::Tiny;

use Trakt;

# Скрипт умеющий запускать процедуру tmin для выбранного сэмпла используя существующий тракт

my $trakt_name = shift;

my $branch_name = shift @ARGV;
die "Укажите имя исследуемой ветки вторым аргументом " unless $branch_name;
my $target_name = shift @ARGV;
die "Укажите имя исследуемой цели третьим аргументом " unless $target_name;

# Директория с корпусом (Опциональная).
my $samples_in_dir = shift @ARGV;

my $trakt = Trakt->create(name => $trakt_name, branch => $branch_name, cert_conf => 'cert.conf');
my $out_dir = path("$target_name.cmin.out")->absolute;

`rm -rf $out_dir`;
`mkdir $out_dir`;
`rm -rf cmin.pgdata`;

my $fuzz_target = $trakt->step('fuzz_afl')->target($target_name);
# Если не указана, то берутся сэмплы из samples_get тракта
$samples_in_dir //= $fuzz_target->sklad->samples->get;

my $instance_env = $fuzz_target->afl_instance_env('cmin.pgdata','.');

my $instance_init_command = $trakt->convoy->instance_init_command('.', 'cmin.pgdata');
`$instance_init_command` if $instance_init_command;

my $cmin_binary = $trakt->intendant->AFLpp->binary('afl-cmin');

my $target_command = $trakt->convoy->command('afl',$target_name,'@@');
{
  local %ENV = (%ENV, %$instance_env);
  my $command = "$cmin_binary -i $samples_in_dir -o $out_dir -- $target_command";
  print "RUNNING: $command\n";
  system("$command");
}

