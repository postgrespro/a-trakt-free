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
             "branch=s"     => \$branch,
             "trakt=s"      => \$trakt,
             "target=s" => \$target,
            );

my $sample_dir = shift @ARGV;

# TODO надо будет добавить trakt-src и trakt-dst чтобы можно было перемещать сэмплы
# между трактами, но прямо сейчас это не надо

die "Укажите --trakt=[имя тракта] внутри которого будем клонировать цель" unless $trakt;
die "Укажите --target=[имя исходной цели]" unless $target;
die "Укажите имя директориии для сохранения сэмплов последним аргуметном" unless $sample_dir;
die "Директория '$sample_dir' не найдена" unless path($sample_dir)->is_dir;


my %opts = (conf => $conf, trakt => $trakt, target=> $target);
$opts{project} = $project if $project;
$opts{branch} = $branch if $branch;

my $res = Samples::get_samples(%opts, path => $sample_dir);

print "Got ",$res->{count}, " samples\n";

die "Что-то пошло не так, для клонируемой цели получено 0 сэмплов. Наверное что-то не так с параметрами" unless $res->{count};

