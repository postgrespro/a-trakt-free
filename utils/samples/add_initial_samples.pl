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
my $conf = $trakt_dir->child('fuzzing.unit-based.#/sample_storage_get/config.json');

  my ($project, $branch, $trakt, $target);
  GetOptions(
             "project=s"    => \$project,
             "trakt=s"      => \$trakt,
             "target=s"     => \$target,
            );

my $sample_dir = path(shift @ARGV);

die "Укажите --trakt=[имя тракта] в которой добавляется цель" unless $trakt;
die "Укажите --target=[имя создаваемой цели]" unless $target;

$branch = 'NONE';

my %opts = (conf => $conf, trakt => $trakt, branch => $branch, target => $target);
$opts{project} = $project if $project;

my @branches = Samples::list_branches(%opts);
my $is_found = 0;
foreach (@branches)
{
  $is_found = 1 if $_ eq $branch;
}
die "Ветка '$branch' не зарегистрирован в хранилище сэмплов" unless $is_found;

my @trakts = Samples::list_trakts(%opts);
$is_found = 0;
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
} else
{
  my $confirm = prompt("Создаваемая цель '$target' уже существует. Это ожидаемо (y/n)?: ", '-y', '-stdio');
  if ($confirm !~/^[yY]$/)
  {
    print "Ну нафиг! \n";
    exit;
  }
}

die "'$sample_dir' -- не директория, не могу добавить сэмплы из нее" unless $sample_dir->is_dir;
die "Директория '$sample_dir' --  пуста, не могу добавить сэмплы из нее" unless $sample_dir->children;


my $count = Samples::upsert_samples(%opts, cert => "initial_samples", samples => [$sample_dir->children]);
print "Добавленно ", $count, " сэмплов\n";

