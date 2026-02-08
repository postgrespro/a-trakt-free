package Trakt::Intendant;

use Moose;
use Path::Tiny;
use Trakt::Intendant::LLVM;
use Trakt::Intendant::AFLpp;


has 'trakt' => (is => 'ro', required => 1, isa => "Trakt");
has 'llvm' =>  (is =>'rw', isa => "Trakt::Intendant::LLVM",  lazy=>1, default=> sub {my $self = shift; Trakt::Intendant::LLVM->new(trakt=>$self->trakt)});
has 'AFLpp' => (is =>'rw', isa => "Trakt::Intendant::AFLpp", lazy=>1, default=> sub {my $self = shift; Trakt::Intendant::AFLpp->new(trakt=>$self->trakt)});

has 'nproc' =>  (is => 'rw', lazy => 1, builder => '_build_nproc');


sub _build_nproc
{
  my $self = shift;
  my $res = `nproc --all`;
  die "Error running nporc -all" unless $res;
  $res += 0; # Убеждаемся что чисто число.
  return $res;
}
1;
