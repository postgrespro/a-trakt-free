package Trakt::Step::TestCoverage::Clang;

use Moose;
extends 'Trakt::Step';

with "Trakt::Role::CoverageLcov";


# У нас тут свой специфический "инстанс": запуск тестов, а не исследуемой программы. Но в остальном все также.

sub instance_env
{
  return {};
}

sub instance_command
{
  my $self = shift;
  return $self->trakt->convoy->test_command('coverage');
}

# Явно очищаем всю директорию cache, чтобы повторные запуски не суммировали полученные профайлы
around 'before_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  my $cache_dir = $self->cache_dir;

  $self->$orig(@args);

  $self->cache_dir->mkpath();
};

around 'core_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  $self->run_enved_command('test_coverage', $self->instance_env, $self->instance_command);
  $self->process_coverage('test_coverage', $self->trakt->convoy->test_affected_binaries('coverage'));

  $self->$orig(@args);
};

1;

package Trakt::Step::TestCoverage::Clang::Target;

use Moose;
extends 'Trakt::Target';

1;
