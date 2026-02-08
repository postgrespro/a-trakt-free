#!/usr/bin/env perl

use FindBin qw( $Bin );
use lib $Bin . '/../lib';

use strict;
use SDL::SecretService;
use Test::More;
use Test::Exception;
use Test::MockObject;
use Path::Tiny;

my $secret_service = SDL::SecretService->new;

throws_ok( sub { $secret_service->get_secrets }, qr/must name of codename in args/, 'expection to die' );
ok( ! $secret_service->get_secrets( 'test' ), 'codename not found in secrets' );

#set mock
my $mock_pathtiny = Test::MockObject->new();
*SDL::SecretService::path = sub { return $mock_pathtiny };
$mock_pathtiny->mock( 'slurp', sub { return '{"project":"shardman","login":"test","password":"pass"}'} );

#test _get_data_from_file
is(
    $secret_service->_get_data_from_file( 'secrets/shardman-deploy-token.conf' ),
    '{"project":"shardman","login":"test","password":"pass"}',
    'should return json string'
);

#test _convert_from_json
is_deeply(
    $secret_service->_convert_from_json( $secret_service->_get_data_from_file( 'secrets/shardman-deploy-token.conf' ) ),
    {project => 'shardman', token => 'test:pass'},
    'should return hashref with data'
);

#test get_secrets
is_deeply(
    $secret_service->get_secrets( 'shardman' ),
    {project => 'shardman', token => 'test:pass'},
    'should return hashref with data'
);

#test retrieve_credentials
is_deeply(
    [ $secret_service->retrieve_credentials( 'shardman' ) ],
    [ 'test', 'pass' ],
    'should return hashref with data'
);

#fail is file not found
$mock_pathtiny->mock( 'slurp', sub { return Path::Tiny::Error->throw('open', 'shardman-deploy-token.conf','not_found') } );
throws_ok( sub { $secret_service->get_secrets( 'shardman' ) }, qr/Error open on 'shardman-deploy-token.conf': not_found/ );

done_testing();
