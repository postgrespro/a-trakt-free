package SDL::Stapel::ReleaseSpec;

use Moose;

has 'edition' => (is => 'rw');
has 'version' => (is => 'rw');
has 'commit'  => (is => 'rw');

# Для обратной совместимости
sub product
{
  my $self = shift;
  return $self->edition(@_);
}

sub git_clone_options
{

}


sub git_pull_options
{

}

sub git_chekout_options
{

}

sub branch
{
  # предположительно вычесляется из имени продукта и версии, но это не точно
}

sub revision
{
  my $self = shift;

  return $self->commit if defined $self->commit;

  return $self->branch;
}



1;
