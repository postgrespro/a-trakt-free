package Trakt::Sklad;

use strict;

use Moose;

use Path::Tiny;

use Trakt::Sklad::Samples;

has 'trakt' => (is => 'ro', required => 1, isa => "Trakt");
has 'name' => (is => 'ro', required => 1, isa => "Str");

has 'samples' => (is => 'ro', required =>1, isa => "Trakt::Sklad::Samples", default=> sub {my $self = shift; Trakt::Sklad::Samples->new(sklad=>$self)});

sub get
{
  my $self = shift;
  my $dir_name = shift;

  my $dir = $self->trakt->exchange_dir->child('_sklad')->child($self->name)->child($dir_name);
  $dir->mkpath;

  return $dir;
}

sub reset
{
  my $self = shift;
  my $dir_name = shift;

  my $dir = $self->trakt->exchange_dir->child('_sklad')->child($self->name)->child($dir_name);
  if ($dir->exists)
  {
    $dir->remove_tree
  }
  $dir->mkpath;

  return $dir;
}
1;
