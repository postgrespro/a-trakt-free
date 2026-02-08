#!/usr/bin/perl

use strict;
use utf8;
use Getopt::Long qw(GetOptions);
use String::ShellQuote;
use Path::Tiny;
use JSON;

my $runner_conf = $ARGV[0];

die "Укажите конфигурациионный файл запускатора первым аргументом" unless $runner_conf;

my $h = JSON->new->decode(path($runner_conf)->slurp);

my $fuzzer = $h->{fuzzer},
my $options = $h->{options},
my $command = $h->{command},
my $masters = $h->{masters},
my $slaves = $h->{slaves},
my $banner = $h->{banner},
my $storage_init_command = $h->{storage_init};
my $env = $h->{env};


$banner = shell_quote($banner);

foreach my $i (2..$masters)
{
  run_instanse("M$i" , 1, 0);
}

foreach my $i (1..$slaves)
{
  run_instanse("Slave$i" , 0, 0);
}

run_instanse('M', 1, 1);



sub run_instanse
{
  my $name = shift;
  my $is_master = shift;
  my $is_in_fg = shift;

  my $option = $is_master ? '-M' : '-S';

  if($storage_init_command)
  {
    my $cmd = $storage_init_command;
    $cmd =~ s/\@INSTANCE_NAME\@/$name/g;
    print "Initializing storage for '$name': $cmd \n";
    system($cmd);
  }

  if (! $is_in_fg)
  {
    my $pid = fork;
    die "failed to fork: $!" unless defined $pid;
    return if $pid; # Мы в родителе, продолжаем запускать другие инстансы
  }

  my $env_str = "";
  foreach my $key (keys %$env)
  {
    $env_str .= " " if $env_str;
    my $value = $env->{$key};
    $value =~ s/\@INSTANCE_NAME\@/$name/g;
    $env_str .= $key."=".shell_quote($value);
  }

  my $command_to_run = "$env_str $fuzzer $options $option $name -T $banner -- $command";
  $command_to_run .= " >/dev/null" unless $is_in_fg;

  print "Runnunt $name: `$command_to_run`";
  system($command_to_run);
  exit(0);
}

