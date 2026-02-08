package SDL::Helling;

use Moose;
use Moose::Util qw( apply_all_roles );

use Path::Tiny;
use String::ShellQuote;

use SDL::Stapel::Postgres;
use SDL::Stapel::AFLpp;
use SDL::SecretService;

has '_sklad' => (is => 'rw', required =>1);
has 'secret_service' => (is => 'rw', isa => 'SDL::SecretService', default => sub { return SDL::SecretService->new; });
has '_postgres_init_args' => (is => 'ro', isa => 'HashRef');
has '_AFLpp_init_args' => (is => 'ro', isa => 'HashRef');


sub sklad
{
  my $self = shift;
  my $dir = shift;
  $self->_sklad($dir) if defined $dir;
  $dir = $self->_sklad if ! defined $dir;

  $dir = path($dir);
  $dir->mkpath unless $dir->is_dir;

  return $dir;
}

sub postgres
{
  my $self = shift;
  my %args = @_;

  my $init_args = $self->_postgres_init_args // {};

  foreach my $key (keys %$init_args)
  {
    $args{$key} //= $init_args->{$key};
  }

  my $extra_roles = $args{extra_roles} || [];
  $extra_roles = [$extra_roles] unless ref $extra_roles;  # Принудительно длеаем списком

  my $res = SDL::Stapel::Postgres->with_traits(@$extra_roles)->new(helling => $self, %args);

  return $res;
}

sub AFLpp
{
  my $self = shift;
  my %args = @_;

  my $extra_roles = $args{extra_roles} || [];
  $extra_roles = [$extra_roles] unless ref $extra_roles;  # Принудительно длеаем списком

  my $res = SDL::Stapel::AFLpp->with_traits(@$extra_roles)->new(helling => $self, %args);

  return $res;
}

sub run_command
{
  my $self = shift;
  my $tag = shift;
  my $command = shift;
  my $opts = shift || {};

  #  my $real_command = "bash -c ".shell_quote("set -o pipefail ; ( $command ) 2>&1 | tee -a $log_name");  # set -o pipefail правильно передает код возврата через пайп
  my $real_command = "bash -c ".shell_quote("set -o pipefail ; ( $command ) 2>&1 ");  # set -o pipefail правильно передает код возврата через пайп

  $SDL::Trakt::Witness::Witness->log_before_command($tag, $command, $real_command) if defined $SDL::Trakt::Witness::Witness;

  if ($opts->{no_out})
  {
    print "Silently executing: $command\n";
    `$real_command`;
     die "Execution failed" if $?;
  } else
  {
    print "Executing: $command\n";
    system($real_command);
    die "Execution failed" if $?;
  }
  $SDL::Trakt::Witness::Witness->log_after_command($tag, $command, $real_command) if defined $SDL::Trakt::Witness::Witness;
}

sub BUILDARGS
{
  my $class = shift;
  my $args = @_==1 ? $_[0] : {@_};  # Берем параметры и из ссылки на хеш и из хеша

  # Если нам в postgres или AFLpp вместо объекта передали хеш, то используем его для инициализации объекта
  $args->{_postgres_init_args} = $args->{postgres} if ref $args->{postgres} eq 'HASH';
  delete $args->{postgres} if ref $args->{postgres} eq 'HASH';

  $args->{_AFLpp_init_args} = $args->{AFLpp} if ref $args->{AFLpp} eq 'HASH';
  delete $args->{AFLpp} if ref $args->{AFLpp} eq 'HASH';

  return $args;
}
1;
