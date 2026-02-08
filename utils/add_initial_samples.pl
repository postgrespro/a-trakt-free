#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/../lib";

use TmuxPaner::RootPane;
use Trakt;
use Trakt::Conf;
use Samples;

# Скрипт позволяющий создавать начальные рандомные сэмплы для целей основанных на LibBlobStamper

my $trakt_name = "fuzzing.unit-based.op.ts";
my $branch_name = 'ent-14'; # 'std-15';

my $trakt = Trakt->create(name => $trakt_name, trakt_path => "..", branch => $branch_name);

my @all_targets = $trakt->targets;

my $samples_conf = $trakt->step('sample_storage_get')->conf_dir()->child('config.json');

print $samples_conf, "\n";


my @existing_targets = Samples::list_targets(conf => $samples_conf, trakt => $trakt_name);
my @missing_targets = ();

my $existing_targets_map = {};

map {$existing_targets_map->{$_}=1} @existing_targets;

foreach my $t (@all_targets)
{
  unless ($existing_targets_map->{$t})
  {
    push @missing_targets, $t;
  }
}

foreach my $t (@missing_targets)
{
  print "Creating target '$t' for trakt '$trakt_name\n'";
  Samples::create_target(conf => $samples_conf, trakt => $trakt_name, target => $t);
}


foreach my $t (@all_targets)
{
`rm -rf tmp`;
`mkdir tmp`;

  print "====== Target: $t\n'";
  my $res = Samples::get_samples(conf => $samples_conf, trakt => $trakt_name, target => $t, path => 'tmp');
  if ($res->{count} == 0)
  {
    print "No samples found. Creating new one\n";
    `dd if=/dev/urandom of=tmp/random count=1`;
    Samples::upsert_samples(conf => $samples_conf, trakt => $trakt_name, target => $t, cert =>'initial_samples', branch => 'NONE', samples => ['tmp/random']);
  }
}

