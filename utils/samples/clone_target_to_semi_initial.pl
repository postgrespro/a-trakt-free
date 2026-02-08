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

  my ($project, $branch, $trakt, $target_src, $target_dst);
  GetOptions(
             "project=s"    => \$project,
             "branch=s"     => \$branch,
             "trakt=s"      => \$trakt,
             "target-src=s" => \$target_src,
             "target-dst=s" => \$target_dst,
            );

# TODO надо будет добавить trakt-src и trakt-dst чтобы можно было перемещать сэмплы
# между трактами, но прямо сейчас это не надо

die "Укажите --trakt=[имя тракта] внутри которого будем клонировать цель" unless $trakt;
die "Укажите --target-src=[имя исходной цели]" unless $target_src;
die "Укажите --target-dst=[имя создаваемого клона цели]" unless $target_dst;
die "Укажите --branch=[имя ветки] в которой это будет происходить"  unless $branch;

my %opts = (conf => $conf, trakt => $trakt, branch =>$branch);
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
  $is_found = 1 if $_ eq $target_src;
}
die "Цель для клонирования '$target_src' не найдена в тракте '$trakt'" unless $is_found;

$is_found = 0;
foreach (@targets)
{
  $is_found = 1 if $_ eq $target_dst;
}
if (! $is_found)
{
  my $confirm = prompt("Создаваемая цель '$target_dst' не существует. Создаем (y/n)?: ", '-y');
  if ($confirm !~/^[yY]$/)
  {
    print "Ну и ладно \n";
    exit;
  }
  Samples::create_target(%opts, target=> $target_dst);
} else
{
  my $confirm = prompt("Создаваемая цель '$target_dst' уже существует. Это ожидаемо (y/n)?: ", '-y');
  if ($confirm !~/^[yY]$/)
  {
    print "Ну нафиг! \n";
    exit;
  }
}

my $tmp_dir = Path::Tiny->tempdir();

my $res = Samples::get_samples(%opts, target=> $target_src, path => $tmp_dir);

print "Got ",$res->{count}, " samples\n";

die "Что-то пошло не так, для клонируемой цели получено 0 сэмплов. Наверное что-то не так с параметрами" unless $res->{count};

my $count = Samples::upsert_samples(%opts, cert => "semi_initial", target=> $target_dst, samples => [$tmp_dir->children]);
print "Cloned ", $count, " samples\n";

