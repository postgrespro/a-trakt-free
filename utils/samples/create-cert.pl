#!/usr/bin/perl

use strict;

use FindBin;
use lib $FindBin::Bin."/../../lib";

use Path::Tiny;
use IO::Prompter;

use Samples;

my $trakt_dir = path($FindBin::Bin)->parent->parent;
my $conf = $trakt_dir->child('fuzzing.unit-based.#/sample_storage_get/config.json');

my $new_cert = shift @ARGV;

die "Укажите имя создаваемой сертификации первым аргументом" unless $new_cert;

my $res = prompt ("Созаем сертификацию '$new_cert'? (y/n)", "-y");

if ($res !~/^[yY]$/)
{
  print "Ну и ладно \n";
  exit;
}

Samples::create_certification(conf => $conf, cert => $new_cert);


