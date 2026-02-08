#!/usr/bin/perl

# Скрипт для "разогрева" новых целей. Запускает фаззинг только тех целей у которых есть только initial сэмплы, и сохраняет резульат как сертификацию с кодовым именем warmup

use strict;

use FindBin;
use lib $FindBin::Bin."/../lib";

use Path::Tiny;
use String::ShellQuote;
use IO::Prompter;
use Trakt;

my $trakt_name = $ARGV[0];

die "Укажите имя тракта первым аргументом" unless $trakt_name;

my $branch_name;

if ($ARGV[1])
{
  $branch_name = $ARGV[1];
} else
{
  $branch_name = "std-17";
  print "Имя ветки не указано вторым аргументом. По умолчанию прогревам цель на ветке std-17\n";
}
my $cert_conf_file = path("cert.conf");

die "Файл $cert_conf_file уже существует. Удалите его чтобы продолжить" if $cert_conf_file->exists();

$cert_conf_file->spew('{"name":"warmup", "is_test":"0"}');

my $trakt = Trakt->create(name => $trakt_name, trakt_path => $FindBin::Bin.'/../trakts', branch => $branch_name, cert_conf => $cert_conf_file);
my $udir = $trakt->top_dir->child("utils/samples");


my $build_step = $trakt->step('build');
my $prepare_step = $trakt->step('prepare_data');

$build_step->run;
$prepare_step->run;

my $trakt_targets = [$trakt->convoy->targets];

print "Ищем цели требующие прогрева:\n";
my $targets_with_initial_samples_only = [];
foreach my $target (@$trakt_targets)
{
  print "$target\n";

  my $certs = `$udir/list-certs.pl --trakt=$trakt_name --target=$target`;

  die "У цели '$target' вообще нет существующих семплов. Прогрев невозможен" if $certs =~/^\s+$/s;

  if ($certs ne "initial_samples\n")
  {
    print "У цели '$target' есть сэмплы отличные от начальных. Прогрев не требуется.\n";
    next;
  }

  push @$targets_with_initial_samples_only, $target;
  print "OK\n";
}

use Data::Dumper;

print Dumper $targets_with_initial_samples_only;

my $exeption_conf =
"
[trakt]

# Запускать только эти цели:
selected_targets = [\"".join('", "',@$targets_with_initial_samples_only) ."\"]
";

path("./$trakt_name.toml")->spew($exeption_conf);

system($trakt->top_dir->child('run_trakt_any.pl')." $trakt_name $branch_name");

