package Trakt::Step::PrepareData;

use strict;

use Moose;
extends 'Trakt::Step';

with 'Trakt::Step::PrepareData::InitDB';

sub do_prepare_data
{

}

augment 'run' => sub {
  my $self = shift;
  $self->do_prepare_data;
}

