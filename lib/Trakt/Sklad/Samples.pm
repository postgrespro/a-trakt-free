package Trakt::Sklad::Samples;

use strict;

use Moose;
use Path::Tiny;
use File::Glob ':bsd_glob';

has 'sklad' => (is => 'ro', required => 1, isa => "Trakt::Sklad");

sub get
{
  my $self = shift;
  return $self->sklad->get('samples');
}

sub reset
{
  my $self = shift;

  return $self->sklad->reset('samples');
}

sub add
{
  my $self = shift;
  my $prefix = shift;
  my $file_mask = shift;

  my $sklad_dir = $self->get;
  $sklad_dir->mkpath;

  foreach my $file (bsd_glob($file_mask))
  {
    $file = path($file);
    next if $file->is_dir;
    my $base = $file->basename;
    $base = $prefix."_".$base if defined $prefix && $prefix ne "";

    my $dst = $sklad_dir->child($base);
    $file->copy($dst);
  }
}
1;
