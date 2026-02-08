#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/../lib";
use Data::Dumper;

use Path::Tiny;

use Trakt;


# Скрипт умеюзий запускать процедуру tmin для выбранного сэмпла используя существующий тракт


my $trakt_conf_dir = shift;

my $trakt_name = path($trakt_conf_dir)->basename;
my $trakt_dir = path($trakt_conf_dir)->parent->absolute;


my $branch_name = shift @ARGV;
die "Укажите имя исследуемой ветки вторым аргументом " unless $branch_name;
my $target_name = shift @ARGV;
die "Укажите имя исследуемой цели третьим аргументом " unless $target_name;
my $sample_in = shift @ARGV;
die "Укажите имя уменьшаемого образца четвертым аргументом " unless $sample_in;

my $sample_out = path(path($sample_in)->basename.".min")->absolute;

my $trakt = Trakt->create(name => $trakt_name, branch => $branch_name, cert_conf => 'cert.conf', trakt_path => $trakt_dir );

`rm -rf cmin.out`;
`mkdir cmin.out`;
`rm -rf cmin.pgdata`;

my $instance_env = $trakt->convoy->instance_env('.', 'cmin.pgdata');
my $instance_init_command = $trakt->convoy->instance_init_command('.', 'cmin.pgdata');
`$instance_init_command` if $instance_init_command;

my $tmin_binary = $trakt->intendant->AFLpp->binary('afl-tmin');


print "EXTRA ENV:\n";
print Dumper $instance_env;

my $target_command = $trakt->convoy->command('afl',$target_name,'@@');
{
  local %ENV = (%ENV, %$instance_env, AFL_MAP_SIZE => 880000, ASAN_OPTIONS=> "detect_leaks=0");
  my $command = "$tmin_binary -i $sample_in -o $sample_out -- $target_command";
  print "RUNNINT $command\n";
  system("$command");
}

my $verbose_command = $trakt->convoy->command('afl',$target_name, $sample_out, {verbose => 1});

print "EXTRA ENV:\n";
print Dumper $instance_env;
{
  local %ENV = (%ENV, %$instance_env, AFL_MAP_SIZE => 880000, ASAN_OPTIONS=> "detect_leaks=0");
  print "RUNNING $verbose_command\n";
  system($verbose_command);
}
