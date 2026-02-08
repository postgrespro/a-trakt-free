#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/../lib";

use Path::Tiny;
use JSON;

use Trakt;
use Test::More;

my $branch_name = 'none';

my $trakt_name = "010_postprocess/postprocess_trakt";

my $tmp_dir = path($FindBin::Bin."/tmp");
$tmp_dir->remove_tree if $tmp_dir->exists;


my $trakt = Trakt->create(name => $trakt_name, branch => $branch_name);
$trakt->work_dir($tmp_dir); # Устанавливаем временную директорию как рабочую директорию тракта...


select(STDERR); # перенаправляем стандартый вывод на STDERR чтобы не мешал тестированию
$trakt->run();
select(STDOUT); #возвращаем стандарный вывод на место и приступаем к тестированию...

my $stat_json_file = $tmp_dir->child('010_postprocess/postprocess_trakt.none.res/target1')->child('stat.json');

ok($stat_json_file->exists, 'stat.json exists');

my $js = JSON->new->allow_nonref;
my $stat_json_hash = $js->decode($stat_json_file->slurp);
my $hangs = $stat_json_hash->{hangs};
my $hangs_total = keys %$hangs;

ok($hangs_total == 3, 'Total Hangs');

my $real_hangs = scalar grep {$hangs->{$_}->{is_real_hang}} keys %$hangs;

ok($real_hangs == 2, 'Real Hangs');

my $crashes = $stat_json_hash->{crashes};
my $crashes_total = keys %$crashes;

ok($crashes_total == 9, 'Total Crashes');

my $confirmed_crashes = scalar grep {$crashes->{$_}->{confirmed}} keys %$crashes;

ok($confirmed_crashes == 8, 'Confirmes Crashes');

my $other_type_crashes = scalar grep {$crashes->{$_}->{crash_type} eq 'other'} keys %$crashes;

ok($other_type_crashes == 1, 'Other Crashes');

my $group1_type_crashes = scalar grep {$crashes->{$_}->{crash_type} eq 'group'} keys %$crashes;

ok($group1_type_crashes == 1, 'ERROR Crashes');

my $group2_type_crashes = scalar grep {$crashes->{$_}->{crash_type} eq 'Assert(AAA)'} keys %$crashes;

ok($group2_type_crashes == 2, 'TRAP Assert(AAA) crashes');

my $group3_type_crashes = scalar grep {$crashes->{$_}->{crash_type} eq 'Assert(BBB)'} keys %$crashes;

ok($group3_type_crashes == 2, 'TRAP Assert(BBB) crashes');

my $group4_type_crashes = scalar grep {$crashes->{$_}->{crash_type} eq 'Assert(CCC)'} keys %$crashes;

ok($group4_type_crashes == 2, 'RUS Assert(CCC) crashes');

$tmp_dir->remove_tree;

done_testing();

