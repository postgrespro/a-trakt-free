#!/usr/bin/perl

use lib './lib';
use Samples;
use strict;
use Getopt::Long;

#use Fuse;

#my ($mountpoint) = "";
#$mountpoint = shift(@ARGV) if @ARGV;
#Fuse::main(mountpoint=>$mountpoint, getattr=>"main::my_getattr", getdir=>"main::my_getdir");

sub new_process_args
{
  my ($cert, $project, $branch, $trakt, $target, $date);
  GetOptions("cert=s"      => \$cert,
             "project=s"   => \$project,
             "branch=s"    => \$branch,
             "trakt=s"     => \$trakt,
             "target=s"    => \$target,
             "date=s"      => \$date );
  my $res = {};
  $res->{cert}    = $cert    if $cert;
  $res->{project} = $project if $project;
  $res->{branch}  = $branch  if $branch;
  $res->{trakt}   = $trakt   if $trakt;
  $res->{target}  = $target  if $target;
  $res->{date}    = $date    if $date;

  return %$res;
}

sub process_args {
    my $conf_name = shift;
    my $command = shift;

    if (! defined $conf_name) {
        die print help(1);
    } elsif (! (defined $command || $conf_name eq '--help' || $conf_name eq '-h')) {
        die print help(0);
    } elsif ($conf_name eq '--help' || $conf_name eq '-h') {
        die print help();
    }

    if ($command eq 'get-samples') {
        shift @ARGV;
        shift @ARGV;
        my %h = new_process_args; Samples::get_samples(%h, conf => $conf_name, path => shift @ARGV);
    }

    if ($command eq 'create-target') {
        shift @ARGV;
        shift @ARGV;
        my %h = new_process_args; Samples::create_target(%h, conf => $conf_name, target => shift @ARGV );
    }
    if ($command eq 'upsert-samples') {
        shift @ARGV;
        shift @ARGV;
        my %h = new_process_args; Samples::upsert_samples(%h, conf => $conf_name, samples => \@ARGV );
    }
    if ($command eq 'list-targets') {
        shift @ARGV;
        shift @ARGV;
        my %h = new_process_args; my @res = Samples::list_targets(%h, conf => $conf_name);
        print join("\n",@res),"\n";
    }
    if ($command eq 'create-trakt') {
        shift @ARGV;
        shift @ARGV;
        my %h = new_process_args; my @res = Samples::create_trakt (%h, conf => $conf_name);
    }

    if ($command eq 'create-branch') {
        shift @ARGV;
        shift @ARGV;
        my %h = new_process_args; my @res = Samples::create_branch (%h, conf => $conf_name, branch=> shift @ARGV);
    }

    if ($command eq 'create-cert') {
        shift @ARGV;
        shift @ARGV;
        my %h = new_process_args; my @res = Samples::create_certification (%h, conf => $conf_name, cert => shift @ARGV);
    }

    if ($command eq 'list-branches') {
        shift @ARGV;
        shift @ARGV;
        my %h = new_process_args; my @res = Samples::list_branches (%h, conf => $conf_name);
        print join("\n", @res), "\n";
    }
    if ($command eq 'list-trakts') {
        shift @ARGV;
        shift @ARGV;
        my %h = new_process_args; my @res = Samples::list_trakts (%h, conf => $conf_name);
        print join("\n", @res), "\n";
    }

    elsif ($command eq 'get') {
        print help(4);
        print help(2);
        Samples::get_sample($conf_name, @_);
    } elsif ($command eq 'put') {
        print help(3);
        Samples::put_sample($conf_name, @_);
    }
    elsif ($command eq 'create-project')      { Samples::create_project         ($conf_name, @_);}
    elsif ($command eq 'delete-project')      { Samples::delete_project         ($conf_name, @_);}
    elsif ($command eq 'delete-cert')         { Samples::delete_certification   ($conf_name, @_);}
    elsif ($command eq 'delete-branch')       { Samples::delete_branch          ($conf_name, @_);}
    elsif ($command eq 'delete-trakt')        { Samples::delete_trakt           ($conf_name, @_);}
    elsif ($command eq 'delete-target')       { Samples::delete_target          ($conf_name, @_);}
    elsif ($command eq 'delete-trakt-target') { Samples::delete_trakt_target    ($conf_name, @_);}
    elsif ($command eq 'latest-cert-branch')  { Samples::get_latest_cert_branch ($conf_name, @_);}
    elsif ($command eq 'latest-cert')         { Samples::get_latest_cert        ($conf_name, @_);}
    elsif ($command eq 'latest-cert-samples') { Samples::get_latest_cert_samples($conf_name, @_);}
    elsif ($command eq 'list-certs')          { Samples::print_list_certs       (conf => $conf_name);}

    Samples::finish($conf_name);
}

sub help {
    my $help_general     = "\nAvailable options: get, put, get-target, get-samples, put-samples, create-project, create-branch, create-trakt, create-target, create-trakt-target.\n";
    my $help_conf        = "\nInput: JSON config file path.\n";
    my $help_select      = "\nSelect query structure: project certification branch trakt_name target name\n";
    my $help_insert      = "\nInsert query structure: path_to_sample project certification branch trakt_name target name\n";
    my $help_get_opts    = "\nCommand \'get\' options: specific row, latest (certification samples).\n";
    my $help_get_latest  = "\nCommand \'get latest\': project certification branch trakt_name target path\n";
    my $help_get_target  = "\nCommand \'get-target\' structure: target_name\n";
    my $help_put_samples = "\nCommand \'upsert-samples\' structure: project certification branch trakt_name target path/samples\n";
    my $help_get_samples = "\nCommand \'get-samples\' structure: project certification branch trakt_name target path/\n";
    my $full_help =<<"HELP";
Samples - Perl package for sending and receiving samples from the DBMS using JSON configuration file.

$help_general
$help_conf
$help_get_opts
$help_select
$help_insert
$help_get_target
$help_put_samples
$help_get_samples
HELP

    if (! defined $_[0]) {
        return $full_help;
    } elsif ($_[0] == 0) {
        return $help_general;
    } elsif ($_[0] == 1) {
        return $help_conf;
    } elsif ($_[0] == 2) {
        return $help_select;
    } elsif ($_[0] == 3) {
        return $help_insert;
    } elsif ($_[0] == 4) {
        return $help_get_opts;
    } elsif ($_[0] == 5) {
        return $help_get_target;
    } elsif ($_[0] == 6) {
        return $help_put_samples;
    }
}

process_args(@ARGV);
