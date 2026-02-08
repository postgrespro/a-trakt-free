#!/usr/bin/perl

use strict;
use Path::Tiny;
use JSON;

my $conf_name = shift @ARGV;

die "Укажите путь к конфигу первым параметром" unless $conf_name;

my $conf = JSON::decode_json(path($conf_name)->slurp);

my $psql_command =  "psql postgresql://".$conf->{user}.":".$conf->{password}."@".$conf->{host}."/". $conf->{dbname};

system($psql_command);