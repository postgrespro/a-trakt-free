package SDL::Stapel::SrcOrigin;

use Moose;


has 'helling' => ( is => 'rw', isa => 'SDL::Helling', required => 1, weak_ref => 1 );

sub get_sources
{
  #my $self = shift;
  #my $release_spec = shift;
  #my $res_dir = shift;

  # Реализовать в наследнках

}

1;
