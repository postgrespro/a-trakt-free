#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/../lib";

use Path::Tiny;

use Trakt;

use Test::More tests => 2;


my $branch_name = 'none';

my $trakt_name = "001_basic_trakt";

my $tmp_dir = path($FindBin::Bin."/tmp");
$tmp_dir->remove_tree if $tmp_dir->exists;


my $trakt = Trakt->create(name => $trakt_name, branch => $branch_name);
$trakt->work_dir($tmp_dir); # Устанавливаем временную директорию как рабочую директорию тракта...


select(STDERR); # перенаправляем стандартый вывод на STDERR чтобы не мешал тестированию
$trakt->run();
select(STDOUT); #возвращаем стандарный вывод на место и приступаем к тестированию...

ok($tmp_dir->child('001_basic_trakt.none.exch')->child('step1.done')->exists, 'step1.done exists');
ok($tmp_dir->child('001_basic_trakt.none.exch')->child('step2.done')->exists, 'step2.done exists');

$tmp_dir->remove_tree;

