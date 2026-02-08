package SDL::Stapel::Flavour::AFLpp;

use Moose::Role;

has AFLpp_dir => (is => 'rw');
has use_asan => (is => 'rw');

around "configure_env" => sub
{
  my $orig = shift;
  my $self = shift;
  my $res = $self->$orig();

  die "Установите свойство AFLpp_dir" unless $self->AFLpp_dir;

  $res->{CC} = ''.$self->AFLpp_dir->child('afl-clang-fast');
  $res->{CXX} = ''.$self->AFLpp_dir->child('afl-clang-fast++');


  if ($self->use_asan)
  {
    $res->{AFL_USE_ASAN}=1;
  }

  return $res;
};

around "compile_env" => sub
{
  my $orig = shift;
  my $self = shift;
  my $res = $self->$orig();

  if ($self->use_asan)
  {
    $res->{AFL_USE_ASAN}=1;
  }

  return $res;
};

around "install_env" => sub
{
  my $orig = shift;
  my $self = shift;
  my $res = $self->$orig();

  if ($self->use_asan)
  {
    $res->{AFL_USE_ASAN}=1;
  }

  return $res;
};


1;
