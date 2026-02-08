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
             "trakt=s"      => \$trakt,
#             "target=s"     => \$target,
            );

my $target = shift @ARGV;

die "Укажите --trakt=[имя тракта] в которой добавляется цель" unless $trakt;
die "Укажите имя создаваемой цели последним аргументом" unless $target;

my $trakt_dir = path($FindBin::Bin)->parent->parent;
my $conf = $trakt_dir->child('fuzzing.unit-based.#/sample_storage_get/config.json');

my $res = prompt ("Созаем цель '$target' в тракте '$trakt'? (y/n)", "-y", "-stdio");

if ($res !~/^[yY]$/)
{
  print "Ну и ладно \n";
  exit;
}

Samples::create_target(conf => $conf, trakt => $trakt, target => $target);


