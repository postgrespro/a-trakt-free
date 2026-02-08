package Trakt::Intendant::LLVM;

use Moose;
use Path::Tiny;

has 'version' => (is => 'rw', lazy => 1, builder => '_version');
has 'trakt' => (is => 'ro', required => 1, isa => "Trakt");

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

# Заполучить команду запуска интересующего бинарника.
# Например $trakt->intendant->llvm->binary('clang') должно в
# вернуть clang-11 или какой там по номеру актуальный
# Можно этот метод переопределять если нам нужен какой-то специальный
# не системный clang
sub binary
{
  my $self = shift;
  my $binary = shift;
  return $binary.'-'.$self->version;
}

1;
