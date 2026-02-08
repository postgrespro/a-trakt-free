#!/usr/bin/perl

use strict;

use Path::Tiny;
use Time::HiRes;
use JSON;

my $json_file_name = shift;
my $json_file = path($json_file_name);
my $js = JSON->new->allow_nonref;
my $params = $js->decode($json_file->slurp);

$| = 1;

if ($params->{type} eq "hang")
{
  my $delay = $params->{hang};
  Time::HiRes::sleep($delay);
  exit;
}

if ($params->{type} eq "crash")
{
  my $crash = $params->{crash};
  if ( $crash == 0 )
  {
    print "There is no crash here\n";
    exit 1;
  }
  if ( $crash == 1 )
  {
    my $cr_type = $params->{cr_type};
    if ( $cr_type eq "error" )
    {
      my $group = $params->{group};
      print "ERROR: AddressSanitizer: $group\n";
      kill(9, $$);
    }
    if ( $cr_type eq "trap" )
    {
      my $assertion = $params->{assertion};
      print "TRAP: FailedAssertion(\"$assertion\")\n";
      kill(9, $$);
    }
    if ( $cr_type eq "ловушка" )
    {
      my $assertion = $params->{assertion};
      print "ЛОВУШКА: нарушение Assert(\"$assertion\")\n";
      kill(9, $$);
    }
    if ( $cr_type eq "other" )
    {
      print "Other crash\n";
      kill(9, $$);
    }
  }
  die "что-то пошло не так";
}
