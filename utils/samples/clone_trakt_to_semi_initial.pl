#!/usr/bin/perl

use strict;

use FindBin;
use lib $FindBin::Bin."/../../lib";

use Path::Tiny;
use IO::Prompter;

use Samples;

my $trakt_dir = path($FindBin::Bin)->parent->parent;

my $src_trakt = shift @ARGV;
die "Укажите название тракта-источника первым аргументом" unless $src_trakt;

my $branch = shift @ARGV;
die "Укажите название ветки вторым аргументом" unless $branch;

my $dst_trakt = shift @ARGV;
die "Укажите название тракта-приемника вторым аргументом" unless $dst_trakt;


# FIXME правильно было бы брать его в конфиге тракта, но и так сойдет...
my $conf = $trakt_dir->child('fuzzing.unit-based.#/sample_storage_get/config.json');


my @branches = Samples::list_branches(conf => $conf);
my @src_targets = Samples::list_targets(conf => $conf, trakt => $src_trakt);
my @trakts = Samples::list_trakts(conf => $conf);

die "Для тракта `$src_trakt` не найденно целей, убедитесь, что вы правилно указали имя" unless @src_targets;

my $is_found = 0;
foreach (@branches)
{
  $is_found = 1 if $_ eq $branch;
}

die "Ветка '$branch' не упомянута в хранилище сэмплов" unless $is_found;

my $is_found = 0;
foreach (@trakts)
{
  $is_found = 1 if $_ eq $dst_trakt;
}

if (! $is_found)
{
  my $res = prompt ("Целевой тракт '$dst_trakt' не найден. Создаем?  (y/n)", "-y");

  if ($res !~/^[yY]$/)
  {
    print "Ну и ладно \n";
    exit;
  }

  Samples::create_trakt(conf => $conf, trakt => $dst_trakt);
}

my @dst_targets = Samples::list_targets(conf => $conf, trakt => $dst_trakt);
my $dst_target_exists  = {map {$_ => 1} @dst_targets};

#use Data::Dumper;
#die Dumper $dst_target_exists;

foreach my $target (@src_targets)
{
  my $tmp_dir = Path::Tiny->tempdir();
  print "Target: $target \n";

  my $res = Samples::get_samples(conf => $conf, trakt => $src_trakt, target=> $target, path => $tmp_dir, branch => $branch);

  print "Got ",$res->{count}, " samples\n";

  if (! $dst_target_exists->{$target})
  {
    print "Создаем ранее не сущетвующую цель '$target' для тракта '$dst_trakt'\n";
    Samples::create_target(conf => $conf, trakt => $dst_trakt, target=> $target);
  }
  my $count = Samples::upsert_samples(conf => $conf, cert => "semi_initial", trakt => $dst_trakt, target=> $target, branch=> $branch, samples => [$tmp_dir->children]);
  print "Cloned ", $count, " samples\n";
}
