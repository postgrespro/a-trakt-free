package SDL::Stapel::Flavour::Coverage;

use Moose::Role;

around "configure_env" => sub
{
  my $orig = shift;
  my $self = shift;
  my $res = $self->$orig();

  my $new_flags = '-O0\ -fprofile-instr-generate\ -fcoverage-mapping';

  $res->{CFLAGS} //='';  # если undefined делаем пробелом
  $res->{CFLAGS} .='\ ' if $res->{CFLAGS};
  $res->{CFLAGS} .= $new_flags;

  $res->{CXXFLAGS} //='';  # если undefined делаем пробелом
  $res->{CXXFLAGS} .='\ ' if $res->{CXXFLAGS};
  $res->{CXXFLAGS} .= $new_flags;

  $res->{LDFLAGS} //='';  # если undefined делаем пробелом
  $res->{LDFLAGS} .='\ ' if $res->{LDFLAGS};
  $res->{LDFLAGS} .= $new_flags;

  return $res;
};


1;
