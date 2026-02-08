#!/usr/bin/perl

use strict;

use FindBin;
use lib $FindBin::Bin."/../../lib";

use Path::Tiny;
use IO::Prompter;

use Samples;

my $trakt_dir = path($FindBin::Bin)->parent->parent;
my $conf = $trakt_dir->child('fuzzing.unit-based.#/sample_storage_get/config.json');

my $new_trakt = shift @ARGV;

die "Укажите имя создаваемого тракта первым аргументом" unless $new_trakt;

my $res = prompt ("Созаем тракт '$new_trakt'? (y/n)", "-y");

if ($res !~/^[yY]$/)
{
  print "Ну и ладно \n";
  exit;
}

Samples::create_trakt(conf => $conf, trakt => $new_trakt);


