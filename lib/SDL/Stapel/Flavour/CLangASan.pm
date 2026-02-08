package SDL::Stapel::Flavour::CLangASan;

use Moose::Role;

around "configure_env" => sub
{
  my $orig = shift;
  my $self = shift;
  my $res = $self->$orig();

  $res->{CFLAGS} = '-fsanitize=address';
  return $res;
};

1;
