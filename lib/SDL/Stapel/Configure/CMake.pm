package SDL::Stapel::Configure::CMake;

use Moose::Role;
use MooseX::RequiresClass;

requires_class 'SDL::Stapel';

use String::ShellQuote;

around "configure_options" => sub
{
  my $orig = shift;
  my $self = shift;
  my $res = $self->$orig();

  my $install_dir = $self->install_dir->absolute;
  $res->{"CMAKE_INSTALL_PREFIX"} = $install_dir;

  # Перекидываем опции компилятора из переменных окружения в опции cmake
  my $env = $self->configure_env();
  foreach my $key (keys %$env)
  {
    if ($key eq 'CC')
    {
      $res->{"CMAKE_C_COMPILER"} = $env->{$key};
    }
    elsif ($key eq 'CXX')
    {
      $res->{"CMAKE_CXX_COMPILER"} = $env->{$key};
    }
    elsif ($key=~/^(C|CXX)FLAGS$/)
    {
      $res->{"CMAKE_$1_FLAGS"} = $env->{$key};
    }
    elsif ($key eq 'LDFLAGS')
    {
      $res->{"CMAKE_EXE_LINKER_FLAGS"} = $env->{$key};
    }
  }

  # FIXME хак позволяющий избавиться от заескепенных пробелов
  # Неаккуратен, надо прсто не эскейпить in the first place
  foreach my $key (qw(CMAKE_C_FLAGS CMAKE_CXX_FLAGS CMAKE_EXE_LINKER_FLAGS))
  {
    next unless $res->{$key};
    $res->{$key} =~ s/\\ / /sg;
  }
  return $res;
};

sub configure_options_string
{
  my $self = shift;

  my $options = $self->configure_options;

  my $res = "";
  foreach my $key (keys %$options)
  {
    $res .= "\\\n" if $res ne "";
    $res .= "-D$key";
    $res .= "=".shell_quote($options->{$key}). " ";
  }
  return $res;
}

sub configure_command
{
  my $self = shift;
  my $src_dir = $self->src_dir->absolute;
  my $build_dir = $self->build_dir->absolute;

  return "cmake ".shell_quote($src_dir). " -B ".shell_quote($build_dir). " ". $self->configure_options_string;
}

1;
