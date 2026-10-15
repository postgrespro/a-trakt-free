package Trakt::Step::Samples::RandomSeed;

use Moose;
extends 'Trakt::Step';

1;

package Trakt::Step::Samples::RandomSeed::Target;

use Moose;
extends 'Trakt::Target';

use Path::Tiny;

around 'core_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;
  $self->$orig(@args);

  warn "Пытаемся сохранить сэмплы для цели с пустым ('') именем. Скорее всего это не то что надо" if $self->name eq '';

  my $samples_path = Path::Tiny->tempdir();

  $samples_path->child('random_seed')->spew_raw( pack 'C*', map { int rand 256 } 1 .. 64 ); # 64 случайных байта

  $self->sklad->samples->add('', $samples_path->child('*'));
};


1;
