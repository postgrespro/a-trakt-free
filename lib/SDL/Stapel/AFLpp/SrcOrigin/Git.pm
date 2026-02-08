package SDL::Stapel::AFLpp::SrcOrigin::Git;


use Moose;
extends 'SDL::Stapel::SrcOrigin::Git';

sub git_spec_from_release_spec
{
  return {code_name => 'AFLpp', https => 'https://github.com/AFLplusplus/AFLplusplus.git'};
}



1;
