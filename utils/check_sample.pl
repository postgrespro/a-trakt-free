#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/../lib";
use Data::Dumper;

use Path::Tiny;

use Trakt;


# Прогнать заданную цель заданного тракта с  заданным сэмплом


my $trakt_conf_dir = shift;

my $trakt_name = path($trakt_conf_dir)->basename;
my $trakt_dir = path($trakt_conf_dir)->parent->absolute;


my $branch_name = shift @ARGV;
die "Укажите имя исследуемой ветки вторым аргументом " unless $branch_name;
my $target_name = shift @ARGV;
die "Укажите имя исследуемой цели третьим аргументом " unless $target_name;
my $sample_in = shift @ARGV;
die "Укажите проверяемого образца четвертым аргументом " unless $sample_in;
$sample_in = path($sample_in)->absolute;


my $trakt = Trakt->create(name => $trakt_name, branch => $branch_name, cert_conf => 'cert.conf', trakt_path => $trakt_dir );

`rm -rf cmin.pgdata`;

my $instance_env = $trakt->convoy->instance_env('.', 'cmin.pgdata');
my $instance_init_command = $trakt->convoy->instance_init_command('.', 'cmin.pgdata');
`$instance_init_command` if $instance_init_command;


my $verbose_command = $trakt->convoy->command('afl',$target_name, $sample_in, {verbose => 1});

print "EXTRA ENV:\n";
print Dumper $instance_env;
{
  local %ENV = (%ENV, %$instance_env, AFL_MAP_SIZE => 880000, ASAN_OPTIONS=> "detect_leaks=0" );
  print "RUNNING $verbose_command\n";
  system($verbose_command);
}
