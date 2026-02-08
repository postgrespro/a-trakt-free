package Local::Convoy;

use FindBin;
use Moose;

extends 'Trakt::Convoy';

sub binary
{
  my $self = shift;
  my $build_name = shift;

  return "$FindBin::Bin/010_postprocess/data/postprocess_proga.pl";
}

sub command
{
  my $self = shift;
  my $build_name = shift;
  my $target = shift;
  my $sample = shift;
  my $options = shift || {};

  return $self->binary($build_name)." $sample";
}

1;
