package SDL::Stapel::AFLpp::DefaultBuildSet;

use Moose::Role;


around "compile_env" => sub
{
  my $orig = shift;
  my $self = shift;
  my $res = $self->$orig();

  $res->{LLVM_CONFIG} = 'llvm-config-14';

  return $res;
};

around "install_env" => sub
{
  my $orig = shift;
  my $self = shift;
  my $res = $self->$orig();

  $res->{PREFIX} = $self->install_dir->absolute;

  return $res;
};


1;
