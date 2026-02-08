package SDL::Stapel::AFLpp::ReleaseSpec;

use Moose;

extends 'SDL::Stapel::ReleaseSpec';

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
  # my $self = shift;
  return 'stable'; #  Пока так
}

1;
