#!/usr/bin/perl

use strict;

use FindBin;
use lib $FindBin::Bin."/../../lib";

use Path::Tiny;
use JSON;


my $trakt_dir = path($FindBin::Bin)->parent->parent;
my $conf_name = $trakt_dir->child('fuzzing.unit-based.#/sample_storage_get/config.json');

my $conf = JSON::decode_json(path($conf_name)->slurp);

my $psql_command =  "psql postgresql://".$conf->{user}.":".$conf->{password}."@".$conf->{host}."/". $conf->{dbname};

print $psql_command,"\n";

system($psql_command);


