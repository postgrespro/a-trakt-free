#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/../lib";
use Trakt;
use Trakt::Step::FuzzAfl;
use Test::More;
use Path::Tiny;
use Test::MockObject;
use JSON;

my $branch_name = 'none';
my $trakt_name  = "001_basic_trakt";

my $trakt = Trakt->create( name => $trakt_name, branch => $branch_name );
$trakt->work_dir( path( $FindBin::Bin. '/' . $trakt_name ) );

my $step = Test::MockObject->new();
*Trakt::step = sub{ return $step };
*Trakt::Target::parent = sub { return $step };
$step->mock('target', sub { return Trakt::Step::FuzzAfl::Target->new( parent => $step, name => 'test' ) } );
$step->mock('parent', sub { return $trakt } );
$step->mock('cache_dir', sub { return path($trakt->cache_dir) } );


# create_dir
$trakt->step('step3')->target('test')->cache_dir->mkdir;

# default
is_deeply( { $trakt->step('step3')->target('test')->read_watchdog_default_limits }, { last_path => '2h 1m' } );
# modify
is_deeply( $trakt->step('step3')->target('test')->modify_watchdog_limits, { limits => { last_path => '1h' } } );
# check modify value
is_deeply( JSON->new->decode( path( $trakt->step('step3')->target('test')->afl_limits_config )->slurp ), { limits => { last_path => '1h' } } );
unlink( $trakt->step('step3')->target('test')->afl_limits_config );

# check default value
my $slurp_mock = Test::MockObject->new();
*Trakt::forced_conf = sub { return {} };
*Trakt::Step::FuzzAfl::Target::path = sub { return  $slurp_mock; };
$slurp_mock->mock('slurp', sub { return '{"limits":{ "last_path":"2h 1m"}}' } );
is_deeply( JSON->new->decode( path( $trakt->step('step3')->target('test')->afl_limits_config )->slurp ), { limits => { last_path => '2h 1m' } } );
unlink( $trakt->step('step3')->target('test')->afl_limits_config );

# clean dir
rmdir $trakt->step('step3')->target('test')->cache_dir;

done_testing();
