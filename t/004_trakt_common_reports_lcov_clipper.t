#!/usr/bin/perl

# Наследуемся от мока и подкидываем ему роль,
# чтобы протестить необходимый метод
package Test::Role;

use Moose;
extends 'Test::MockObject';

with 'Trakt::Step::Reports::LCovClipperTarget';

sub core_run {};

1;
############################################

use strict;
use FindBin;
use lib $FindBin::Bin."/../lib";

use Test::More;
use Trakt::Step::Reports::LCovClipperTarget;
use Test::Role;
use Test::MockObject;
use Test::Exception;

my $role = Trakt::Step::Reports::LCovClipperTarget->meta;

isa_ok( $role, 'Moose::Meta::Role' );
is( $role->name, 'Trakt::Step::Reports::LCovClipperTarget', 'got name Trakt::Step::Reports::LCovClipperTarget' );
ok( Trakt::Step::Reports::LCovClipperTarget->can( 'is_range_within_bounds' ), 'defined method is_range_within_bounds' );


my $test_role = Test::Role->new;
my $trakt = Test::MockObject->new;
my $convoy = Test::MockObject->new;
$test_role->mock( 'trakt', sub { return $trakt; } );
$trakt->mock( 'convoy', sub { return $convoy } );

#test digit value
$convoy->mock( 'project_version_major', sub { return '13'; } );

throws_ok(
  sub { $test_role->is_range_within_bounds( 'clipper.1,2e,3.conf' ) },
  qr/Invalid range format: '2e'/
);
ok( $test_role->is_range_within_bounds( 'clipper.13+.conf' ) );
ok( $test_role->is_range_within_bounds( 'clipper.11-14.conf' ) );
ok( ! $test_role->is_range_within_bounds( 'clipper.conf' ) );


#valid branch in conf
$convoy->mock( 'project_version_major', sub { return 'std-13'; } );
ok( $test_role->is_range_within_bounds( 'clipper.std-13.conf' ) );

$convoy->mock( 'project_version_major', sub { return 'ent-13'; } );
ok( $test_role->is_range_within_bounds( 'clipper.ent-13.conf' ) );

$convoy->mock( 'project_version_major', sub { return 'REL_13'; } );
ok( $test_role->is_range_within_bounds( 'clipper.REL_13.conf' ) );

#test corp branch with digit value
$convoy->mock( 'project_version_major', sub { return 'std-13'; } );
ok( $test_role->is_range_within_bounds( 'clipper.1,2,3,10-20,std-13.conf' ) );

$convoy->mock( 'project_version_major', sub { return 'ent-13'; } );
ok( $test_role->is_range_within_bounds( 'clipper.1,2,3,10-20,ent-13.conf' ) );

$convoy->mock( 'project_version_major', sub { return 'REL_13'; } );
ok( $test_role->is_range_within_bounds( 'clipper.1,2,3,10-20,REL_13.conf' ) );

$convoy->mock( 'project_version_major', sub { return 'std-14'; } );
ok( $test_role->is_range_within_bounds( 'clipper.1,2,3,10-20,std-(13-16).conf' ) );

done_testing();
