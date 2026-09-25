#!/usr/bin/perl

use strict;

use FindBin;
use lib $FindBin::Bin."/../../lib";

use Path::Tiny;
use IO::Prompter;
use Getopt::Long;

use Samples;

my ($project, $trakt, $target);
  GetOptions(
             "project=s"    => \$project,
#             "trakt=s"      => \$trakt,
#             "target=s"     => \$target,
            );

my $trakt_dir = path($FindBin::Bin)->parent->parent;
my $conf = $trakt_dir->child('fuzzing.unit-based.#/sample_storage_get/config.json');

my $new_branch = shift @ARGV;

die "Укажите --project=[имя проекта] в которой создается ветка" unless $project;
die "Укажите имя создаваемой ветки последним аргументом" unless $new_branch;

my $res = prompt ("Созаем ветку '$new_branch' в проекте '$project'? (y/n)", "-y");

if ($res !~/^[yY]$/)
{
  print "Ну и ладно \n";
  exit;
}

Samples::create_branch(conf => $conf, branch => $new_branch, project => $project);


