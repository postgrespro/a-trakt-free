#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/lib";

use Path::Tiny;

use Trakt;

my $trakt_conf_dir = shift @ARGV;

my $trakt_name = path($trakt_conf_dir)->basename;
my $trakt_dir = path($trakt_conf_dir)->parent;

my $branch_name = shift @ARGV;
die "Укажите вторым аргументом имя исследуемой ветки или путь tarball'у с дистрибутивом" unless $branch_name;

my $tarball = undef;

if (-e $branch_name)
{
  $tarball = $branch_name;
  $branch_name = undef;
}

if ("$trakt_conf_dir" eq "$trakt_name")
{
  # Если директорию нам не указали, провериим, нет ли тракта с таким именем в директории trakts
  if (path($FindBin::Bin)->child('trakts')->child($trakt_name)->child('trakt.conf')->exists)
  {
    $trakt_dir = path('trakts');
  }
}

my $trakt_init_args = {
  name => $trakt_name,
  cert_conf => 'cert.conf',
};

$trakt_init_args->{branch} = $branch_name if $branch_name;
$trakt_init_args->{tarball} = $tarball if $tarball;

$trakt_init_args->{trakt_path} = $trakt_dir if $trakt_dir;

my $trakt = Trakt->create(%$trakt_init_args);

$trakt->run;
