package SDL::Stapel::BuildSet;

use Moose::Role;

with 'SDL::Stapel::PatchSet';


sub configure_options
{
	return {};
}

sub configure_env
{
	return {};
}

sub configure_env_string
{
	my $self = shift;
	return $self->_env_string($self->configure_env);
}

sub compile_env
{
	return {};
}

sub compile_env_string
{
	my $self = shift;
	return $self->_env_string($self->compile_env);
}

sub install_env
{
	return {};
}

sub install_env_string
{
	my $self = shift;
	return $self->_env_string($self->install_env);
}

sub context_setup_env
{
  return {};
}

sub context_setup_env_string
{
  my $self = shift;
  return $self->_env_string($self->context_setup_env);
}

sub _env_string
{
  my $self = shift;
  my $env = shift;
  my $res = "";
  foreach my $key (keys %$env)
  {
    $res .= " " unless $res eq "";
    $res .= "$key=";
    $res .= $env->{$key};
  }
  return $res;
}

1;
