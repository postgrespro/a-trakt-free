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

  my ($project, $branch, $cert, $trakt, $target);
  GetOptions(
             "project=s"    => \$project,
             "branch=s"     => \$branch,
             "cert=s"       => \$cert,
             "trakt=s"      => \$trakt,
             "target=s"     => \$target,
            );



die "Укажите --trakt=[имя тракта] в которой добавляются сэмплы" unless $trakt;
die "Укажите --branch=[имя ветки] в которцю добавляются сэмплы" unless $branch;
die "Укажите --cert=[имя сертификации] в которцю добавляются сэмплы" unless $cert;
die "Укажите --target=[имя создаваемой цели]" unless $target;

my $sample_dir = shift @ARGV;

die "Укажите имя директории с сэмплами последним аргуметном" unless $sample_dir;

$sample_dir = path($sample_dir);

my %opts = (conf => $conf, trakt => $trakt, branch => $branch, target => $target, cert => $cert );
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
die "Цель '$target' не найдена в тракте '$trakt'" unless $is_found;

my @certs = Samples::list_certs(%opts);
$is_found = 0;
foreach (@certs)
{
  $is_found = 1 if $_ eq $cert;
}
die "Сертификация '$cert' не зарегистрирован в хранилище сэмплов" unless $is_found;


die "'$sample_dir' -- не директория, не могу добавить сэмплы из нее" unless $sample_dir->is_dir;
die "Директория '$sample_dir' --  пуста, не могу добавить сэмплы из нее" unless $sample_dir->children;

print "branch = '$branch'\n";
print "cert = '$cert'\n";
print "trakt = '$trakt'\n";
print "target = '$target'\n";
print "Директория '$sample_dir' содержит ". int($sample_dir->children)." файлов\n";


my $res = prompt ("Добавляем? (y/n)", "-y", "-stdio");
if ($res !~/^[yY]$/)
{
  print "Ну и ладно \n";
  exit;
}

my $count = Samples::upsert_samples(%opts, samples => [$sample_dir->children]);
print "Добавленно ", $count, " сэмплов\n";

