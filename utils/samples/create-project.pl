#!/usr/bin/perl

use strict;

use FindBin;
use lib $FindBin::Bin."/../../lib";

use Path::Tiny;
use IO::Prompter;

use Samples;

my $trakt_dir = path($FindBin::Bin)->parent->parent;
my $conf = $trakt_dir->child('fuzzing.unit-based.#/sample_storage_get/config.json');

my $new_project = shift @ARGV;

die "Укажите имя создаваемого проекта первым аргументом" unless $new_project;

my $res = prompt ("Созаем проект '$new_project'? (y/n)", "-y");

if ($res !~/^[yY]$/)
{
  print "Ну и ладно \n";
  exit;
}

Samples::create_project(conf => $conf, project => $new_project);


