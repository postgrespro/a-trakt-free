package SDL::Stapel::Flavour::ClangCoverage;

use Moose::Role;

around "configure_env" => sub
{
  my $orig = shift;
  my $self = shift;
  my $res = $self->$orig();

  my $new_flags = '-O0\ -fprofile-instr-generate\ -fcoverage-mapping';

  $res->{CC} = 'clang-14'; # FIXME сюда надо как-то прикрутить интенданта, чтобы он правильно определял версию clang'а
  $res->{CXX} = 'clang++-14'; # FIXME сюда надо как-то прикрутить интенданта, чтобы он правильно определял версию clang'а

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
