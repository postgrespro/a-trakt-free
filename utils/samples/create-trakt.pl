#!/usr/bin/perl

use strict;

use FindBin;
use lib $FindBin::Bin."/../../lib";

use Path::Tiny;
use Getopt::Long;
use IO::Prompter;

use Samples;

my ($project, $trakt, $target);
  GetOptions(
             "project=s"    => \$project,
#             "trakt=s"      => \$trakt,
#             "target=s"     => \$target,
            );

my $trakt_dir = path($FindBin::Bin)->parent->parent;
my $conf = $trakt_dir->child('fuzzing.unit-based.#/sample_storage_get/config.json');

my $new_trakt = shift @ARGV;

die "Укажите --project=[имя проекта] в которой добавляется тракт" unless $project;
die "Укажите имя создаваемого тракта последним аргументом" unless $new_trakt;



my $res = prompt ("Созаем тракт '$new_trakt' в проекте '$project'? (y/n)", "-y");

if ($res !~/^[yY]$/)
{
  print "Ну и ладно \n";
  exit;
}

Samples::create_trakt(conf => $conf, project => $project, trakt => $new_trakt);


