#!/usr/bin/perl

use strict;

use FindBin;
use lib $FindBin::Bin."/../../lib";

use Path::Tiny;
use IO::Prompter;
use Getopt::Long;

use Samples;

my $trakt_dir = path($FindBin::Bin)->parent->parent;
# FIXME правильно было бы брать его в конфиге тракта, но и так сойдет...
my $conf = $trakt_dir->child('fuzzing.#/sample_storage_get/config.json');

  my ($project, $branch, $cert, $trakt, $target);
  GetOptions(
             "project=s"    => \$project,
             "branch=s"     => \$branch,
             "trakt=s"      => \$trakt,
             "cert=s"       => \$cert,
             "target=s"     => \$target,
            );

die "Укажите --cert=[кодовое имя сертификации]" unless $cert;
die "Укажите --branch=[имя ветки]" unless $branch;
die "Укажите --trakt=[имя тракта]" unless $trakt;
die "Укажите --target=[имя цели]" unless $target;


my %opts = (conf => $conf, trakt => $trakt, branch => $branch, target => $target, cert => $cert);
$opts{project} = $project if $project;

my @sample_names = Samples::list_samples(%opts);

foreach (@sample_names)
{
  print $_,"\n";
}

