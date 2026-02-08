package SDL::Stapel::ParamSet;

use Moose;

has options => (is => 'rw', builder => 'options_defaults');
has environment  => (is => 'rw', builder => 'environment_defaults');

sub options_defaults
{
  return {};
}


sub environment_defaults
{
  return {};
}

sub environment_string
{
  my $self = shift;
  my $env = $self->environment;
  my $res = "";
  foreach my $key (keys %$env)
  {
    $res .= " " unless $res eq "";
    $res .= "$key=";
    $res .= $env->{$key};
  }
  return $res;
}

sub options_string
{

}

1;
