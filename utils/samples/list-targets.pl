#!/usr/bin/perl

use strict;

use FindBin;
use lib $FindBin::Bin."/../../lib";
use Getopt::Long;

use Path::Tiny;

use Samples;

my $trakt_dir = path($FindBin::Bin)->parent->parent;
my $conf = $trakt_dir->child('fuzzing.unit-based.#/sample_storage_get/config.json');

my ($trakt);

  GetOptions(
             "trakt=s"      => \$trakt,
            );

# TODO надо будет добавить trakt-src и trakt-dst чтобы можно было перемещать сэмплы
# между трактами, но прямо сейчас это не надо

die "Укажите --trakt=[имя тракта] внутри которого будем клонировать цель" unless $trakt;


my @targets = Samples::list_targets(conf => $conf, trakt => $trakt);

foreach (@targets)
{
  print $_,"\n";
}
