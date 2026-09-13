#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/lib";

use Path::Tiny;

use Trakt;

my $trakt_conf_dir = shift @ARGV;

my ($trakt_dir, $trakt_name) = Trakt->split_trakt_path($trakt_conf_dir);

my $branch_name = shift @ARGV;
die "Укажите вторым аргументом имя исследуемой ветки или путь tarball'у с дистрибутивом" unless $branch_name;

my $tarball = undef;

if (-e $branch_name)
{
  $tarball = $branch_name;
  $branch_name = undef;
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
