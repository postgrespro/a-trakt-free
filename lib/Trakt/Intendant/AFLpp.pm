package Trakt::Intendant::AFLpp;

use Moose;
use Path::Tiny;

# has 'version' => (is => 'rw', lazy => 1, builder => '_version');
has 'trakt' => (is => 'ro', required => 1, isa => "Trakt");
has 'binary_dir' => (is => 'rw', lazy => 1, builder => '_lazy_binary_dir');

=cut
sub _version
{
  my $self = shift;
  my $res = undef;
  foreach my $file (path('/usr/bin/')->children(qr/clang-\d\d/))
  {
    $file=~m{/clang-(\d\d)$};
    $res = $1 if ! defined $res || $res < $1;
  }
  die "clang not found" unless defined $res;
  return $res;
}
=cut

# По умолчанию ищем AFL++ в директории сборки исследуемой программы с AFL++.
# Если надо как-то еще, то переопределите либо метод, либо задайте значение по умолчанию при инициализаици

sub _lazy_binary_dir
{
  my $self = shift;
  my $stapel_afl = $self->trakt->step('build')->target('afl')->afl_stapel;
  my $afl_path = $stapel_afl->install_dir->absolute->child('bin');
  return $afl_path;
}

# Заполучить команду запуска интересующего бинарника.
# Например $trakt->intendant->AFLpp->binary('fuzz-afl')

sub binary
{
  my $self = shift;
  my $binary = shift;

  die "binary_dir is not set. You should set it somewhere to make it work" unless defined $self->binary_dir;

  return path($self->binary_dir)->child($binary);
}

1;
