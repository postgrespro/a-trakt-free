#!/usr/bin/perl

use strict;

use FindBin;
use lib $FindBin::Bin."/../../lib";

use Path::Tiny;
use IO::Prompter;

use Samples;

my $trakt_dir = path($FindBin::Bin)->parent->parent;
my $conf = $trakt_dir->child('fuzzing.unit-based.#/sample_storage_get/config.json');

my $new_branch = shift @ARGV;

die "Укажите имя создаваемой ветки первым аргументом" unless $new_branch;

my $res = prompt ("Созаем ветку '$new_branch'? (y/n)", "-y");

if ($res !~/^[yY]$/)
{
  print "Ну и ладно \n";
  exit;
}

Samples::create_branch(conf => $conf, branch => $new_branch);


