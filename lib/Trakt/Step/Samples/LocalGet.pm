package Trakt::Step::Samples::LocalGet;

use Moose;
extends 'Trakt::Step';

1;

package Trakt::Step::Samples::LocalGet::Target;

use Moose;
extends 'Trakt::Target';

use Path::Tiny;

around 'core_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;
  $self->$orig(@args);

  print "using local path as sapmles soure: '".$self->step->conf()->{samples_path}."'\n";

  warn "Пытаемся сохранить сэмплы для цели с пустым ('') имененм. Скорее всего это не то что надо" if $self->name eq '';

  my $samples_path = path($self->step->conf()->{samples_path})->child($self->name);
  $self->sklad->samples->add('', $samples_path->child('*'));
};


1;
