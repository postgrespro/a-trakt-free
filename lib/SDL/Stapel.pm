package SDL::Stapel;

use Moose;
use Moose::Util::TypeConstraints;

with 'MooseX::Traits', 'SDL::Stapel::BuildSet';

use Path::Tiny;
use String::ShellQuote;
use File::Copy::Recursive qw(rcopy);

use SDL::Stapel::SrcOrigin::Git;



class_type 'Path::Tiny';
coerce 'Path::Tiny'
  => from 'Str',
  => via {path($_)->absolute};

has release_spec => (is => 'rw', isa => 'SDL::Stapel::ReleaseSpec');
has src_origin_class => (is => 'ro', default => 'SDL::Stapel::SrcOrigin::Git');
has src_origin => (is=>'ro', lazy => 1, default => sub {my $self = shift; return $self->src_origin_class->new(helling => $self->helling, %{$self->_src_origin_init_args})});
has '_src_origin_init_args' => (is => 'ro', isa => 'HashRef');


has git => (is => 'rw', lazy => 1, default => sub {my $self = shift; return $self->helling->git->postgres});

has src_dir => (is => 'rw', isa => 'Path::Tiny', coerce => 1);
has build_dir => (is =>'rw', isa => 'Path::Tiny', coerce => 1);

has install_dir=> (is =>'rw', isa => 'Path::Tiny', coerce => 1);
has skip_install => (is=>"rw", isa => "Bool", default => 0);

has context_data_dir => (is =>'rw', isa => 'Path::Tiny', coerce => 1);
has skip_context_setup => (is=>"rw", isa => "Bool", default => 0);


# Нюанс in source сборки: мы все равно создаем директории src и build, для единообразия
# Но в случае in source сборки копируем все исходники в build директорию перед сборкой
has is_insource_build => (is => 'rw', isa => 'Bool', default => 0);

has 'helling' => (is => 'rw', isa => 'SDL::Helling', required => 1, weak_ref => 1 );


# Директория в которой находится скрипт конфигурации.
# При out of source сборке он в директории src
# При in source сборке он оказывается в директории build
sub configure_dir
{
  my $self = shift;

  return $self->build_dir if $self->is_insource_build;
  return $self->src_dir;
}

sub prepare_src
{
  my $self = shift;

  my $src_dir = $self->src_dir->absolute;
  $src_dir->remove_tree( { safe => 0 } );
  $src_dir->mkpath();

  $self->src_origin->get_sources($self->release_spec, $src_dir);

  foreach my $patch (@{$self->patches})
  {
    $patch = path($patch)->absolute;
    $patch = shell_quote($patch);
    $self->helling->run_command('prepare_src', "cd $src_dir ; patch -p1 < $patch");
  }

  foreach my $dir (@{$self->dirs})
  {
    $dir = path($dir)->absolute;
    $self->helling->run_command('prepare_src', "cp -R --dereference $dir/. $src_dir"); # '/.' чтобы скопировал всё содержимое, а не саму директорию
  }
}

sub configure_command
{
  # Команда запуска конфигурциаи. Без переменных окружения и перехода в директорию сборки, но с опциями конфигурайи..
  # Для каждого стапеля реализуется индивидуально
  # my $self = shift;
  # my $configure_dir = $self->configure_dir->absolute;
  #
  # return "$configure_dir/configure ".$self->configure_params->options_string;
  die "configure_command not implemented";
}

sub configure
{
  my $self = shift;
  my $configure_command = $self->configure_command;

  my $command = "cd ".$self->build_dir."; ".$self->configure_env_string." $configure_command";

  print "=============================== \n $command\n\n\n";
  $self->helling->run_command('configure', $command);
}

sub compile
{
  my $self = shift;
  my $env = $self->compile_env_string;

 $self->helling->run_command('compile', "$env make -C ".$self->build_dir." -j8"); # FIXME получать количество CPU у интенданта
}

sub install
{
  my $self = shift;
  my $env = $self->install_env_string;

  $self->helling->run_command('install', "$env make -C ".$self->build_dir." install");
}

# Дополнительные действия после установки которые разворачивают нужный контекст для работы продукта.
# В случае PostgreSQL -- initdb, в иных случаях какие-то еще штуки могут быть

sub context_setup
{
  my $self = shift;

}

sub build
{
  my $self = shift;
  $self->prepare_src();

  my $src_dir = $self->src_dir->absolute;

  $self->build_dir->remove_tree( { safe => 0 } );
  $self->build_dir->mkpath();

  rcopy($self->src_dir, $self->build_dir) if $self->is_insource_build;

  $self->configure;

  $self->compile();
  $self->install()       unless $self->skip_install;
  $self->context_setup() unless $self->skip_context_setup;
}

sub BUILDARGS
{
  my $class = shift;
  my $args = @_==1 ? $_[0] : {@_};  # Берем параметры и из ссылки на хеш и из хеша

  # Если нам в postgres или AFLpp вместо объекта передали хеш, то используем его для инициализации объекта
  $args->{_src_origin_init_args} = $args->{src_origin} if ref $args->{src_origin} eq 'HASH';
  delete $args->{src_origin} if ref $args->{src_origin} eq 'HASH';
  $args->{_src_origin_init_args} //= {};

  return $args;
}

1;
