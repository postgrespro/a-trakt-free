#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/../lib";

use Trakt::Convoy;
use Trakt;
use Test::MockObject;

use Test::More;

my $trakt_mock = Test::MockObject->new;
$trakt_mock->set_isa('Trakt');

my $convoy = Trakt::Convoy->new(
    trakt => $trakt_mock,
);

# tests project_version_major
$trakt_mock->mock('conf', sub { return { branch => 'shardman' } });
is $convoy->project_version_major, 14, 'should return 14';
$trakt_mock->mock('conf', sub { return { branch => 'shardman-dev' } });
is $convoy->project_version_major, 14,  'should return 14';
$trakt_mock->mock('conf', sub { return { branch => 'master' } });
is $convoy->project_version_major, 16,  'should return 14';
$trakt_mock->mock('conf', sub { return { branch => 'REL_12' } });
is $convoy->project_version_major, 12,  'should return 12';
$trakt_mock->mock('conf', sub { return { branch => 'std-12' } });
is $convoy->project_version_major, 12,  'should return 12';
$trakt_mock->mock('conf', sub { return { branch => 'ent-12' } });
is $convoy->project_version_major, 12,  'should return 12';

done_testing();
