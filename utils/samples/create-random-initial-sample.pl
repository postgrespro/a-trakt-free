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

  my ($project, $branch, $trakt, $target, $cert);
  GetOptions(
             "project=s"    => \$project,
             "trakt=s"      => \$trakt,
             "target=s"     => \$target,
            );

die "Укажите --trakt=[имя тракта] в которой добавляется цель" unless $trakt;
die "Укажите --target=[имя создаваемой цели]" unless $target;

$branch = 'NONE';
$cert = 'initial_samples';

my %opts = (conf => $conf, trakt => $trakt, branch => $branch, target => $target, cert => $cert);
$opts{project} = $project if $project;

my @trakts = Samples::list_trakts(%opts);
my $is_found = 0;
foreach (@trakts)
{
  $is_found = 1 if $_ eq $trakt;
}
die "Тракт '$trakt' не зарегистрирован в хранилище сэмплов" unless $is_found;

my @targets = Samples::list_targets(%opts);
$is_found = 0;
foreach (@targets)
{
  $is_found = 1 if $_ eq $target;
}
if (! $is_found)
{
  my $confirm = prompt("Создаваемая цель '$target' не существует. Создаем (y/n)?: ", '-y', '-stdio');
  if ($confirm !~/^[yY]$/)
  {
    print "Ну и ладно \n";
    exit;
  }
  Samples::create_target(%opts, target=> $target);
}
my $tmp_file = Path::Tiny->tempfile;

my $exists_map={};
foreach my $sample_name (Samples::list_samples(%opts))
{
  $exists_map->{$sample_name} = 1;
}

while ($exists_map->{$tmp_file->basename})
{
  $tmp_file = Path::Tiny->tempfile;
}

my $confirm = prompt("Создаем сэмпл со случайными данными с именем '".$tmp_file->basename."' (y/n)?: ", '-y', '-stdio');
if ($confirm !~/^[yY]$/)
{
  print "Ну и ладно \n";
  exit;
}

`dd if=/dev/random of=$tmp_file count=1`;

my $count = Samples::upsert_samples(%opts, samples => [$tmp_file]);
print "Добавленно ", $count, " сэмплов\n";

