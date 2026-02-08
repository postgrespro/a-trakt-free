#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/../../../lib";

use Path::Tiny;

use Test::More tests => 28;

my $sample = 'cr0san0_group1';
my $res = `./postprocess_proga.pl crashes/$sample.json`;
my $exit_code = $? >> 8;
my $signal_num = $? & 127;
my $san =  $res =~ m{ERROR: AddressSanitizer: (\S+)}s;

ok($exit_code == 1, "$sample: exit_code = 1");
ok($signal_num == 0, "$sample: signal_num = 0");
ok($san == 0, "$sample: san = 0");

$sample = 'cr0san0_group2';
$res = `./postprocess_proga.pl crashes/$sample.json`;
$exit_code = $? >> 8;
$signal_num = $? & 127;
$san =  $res =~ m{ERROR: AddressSanitizer: (\S+)}s;

ok($exit_code == 1, "$sample: exit_code = 1");
ok($signal_num == 0, "$sample: signal_num = 0");
ok($san == 0, "$sample: san = 0");

$sample = 'cr0san1_group1';
$res = `./postprocess_proga.pl crashes/$sample.json`;
$exit_code = $? >> 8;
$signal_num = $? & 127;
$san =  $res =~ m{ERROR: AddressSanitizer: (\S+)}s;
my $res_group = $1;

ok($exit_code == 1, "$sample: exit_code = 1");
ok($signal_num == 0, "$sample: signal_num = 0");
ok($san == 1, "$sample: san = 1");
ok($res_group eq 'group1', "$sample: res_group = group1");

$sample = 'cr0san1_group2';
$res = `./postprocess_proga.pl crashes/$sample.json`;
$exit_code = $? >> 8;
$signal_num = $? & 127;
$san =  $res =~ m{ERROR: AddressSanitizer: (\S+)}s;
my $res_group = $1;

ok($exit_code == 1, "$sample: exit_code = 1");
ok($signal_num == 0, "$sample: signal_num = 0");
ok($san == 1, "$sample: san = 1");
ok($res_group eq 'group2', "$sample: res_group = group2");

$sample = 'cr1san0_group1';
$res = `./postprocess_proga.pl crashes/$sample.json`;
$exit_code = $? >> 8;
$signal_num = $? & 127;
$san =  $res =~ m{ERROR: AddressSanitizer: (\S+)}s;

ok($exit_code == 0, "$sample: exit_code = 0");
ok($signal_num == 9, "$sample: signal_num = 9");
ok($san == 0, "$sample: san = 0");

$sample = 'cr1san0_group2';
$res = `./postprocess_proga.pl crashes/$sample.json`;
$exit_code = $? >> 8;
$signal_num = $? & 127;
$san =  $res =~ m{ERROR: AddressSanitizer: (\S+)}s;

ok($exit_code == 0, "$sample: exit_code = 0");
ok($signal_num == 9, "$sample: signal_num = 9");
ok($san == 0, "$sample: san = 0");

$sample = 'cr1san1_group1';
$res = `./postprocess_proga.pl crashes/$sample.json`;
$exit_code = $? >> 8;
$signal_num = $? & 127;
$san =  $res =~ m{ERROR: AddressSanitizer: (\S+)}s;
$res_group = $1;

ok($exit_code == 0, "$sample: exit_code = 0");
ok($signal_num == 9, "$sample: signal_num = 9");
ok($san == 1, "$sample: san = 1");
ok($res_group eq 'group1', "$sample: res_group = group1");

$sample = 'cr1san1_group2';
$res = `./postprocess_proga.pl crashes/$sample.json`;
$exit_code = $? >> 8;
$signal_num = $? & 127;
$san =  $res =~ m{ERROR: AddressSanitizer: (\S+)}s;
my $res_group = $1;

ok($exit_code == 0, "$sample: exit_code = 0");
ok($signal_num == 9, "$sample: signal_num = 9");
ok($san == 1, "$sample: san = 1");
ok($res_group eq 'group2', "$sample: res_group = group2");

