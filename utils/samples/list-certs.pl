#!/usr/bin/perl

use strict;

use FindBin;
use lib $FindBin::Bin."/../../lib";
use Getopt::Long;

use Path::Tiny;

use Samples;

my ($project, $trakt, $target);
  GetOptions(
             "project=s"    => \$project,
             "trakt=s"      => \$trakt,
             "target=s"     => \$target,
            );

if ( ( $trakt && !$target ) ||
     (!$trakt &&  $target ) )
{
   die "Опции --trakt и --target должны быть указаны обе одновремнно или обе не указаны";
}

my $trakt_dir = path($FindBin::Bin)->parent->parent;
my $conf = $trakt_dir->child('fuzzing.unit-based.#/sample_storage_get/config.json');

my %opts = (conf => $conf);
$opts{project} = $project if $project;
$opts{target}  = $target  if $target;
$opts{trakt}   = $trakt   if $trakt;

my @certs = Samples::list_certs(%opts);

foreach (@certs)
{
  print $_,"\n";
}
