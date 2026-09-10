package Trakt::Conf2;

use Moose::Role;
#use MooseX::RequiresClass;

#requires_class 'Trakt';

use JSON;
use Path::Tiny;
use TOML::Tiny qw( from_toml );

has "conf2" => (is =>'rw', lazy => 1, builder => '_conf_lazy');
has "forced_conf" => (is =>'rw', lazy => 1, builder => '_read_forced_conf');

sub _conf_lazy
{
  my $self = shift;
  my $conf_dir = $self->conf_dir;

  my $trakt_conf_file = $conf_dir->child("trakt.conf");

  my $res = $self->_read_trakt_conf($trakt_conf_file);

  return $res;
}

sub _read_trakt_conf
{
  my $self = shift;  # может вызываться из метода класса, поэтому использовать нельзя
  my $trakt_conf_file = shift;

  my $json = JSON->new->relaxed;

  my $res = $json->decode(path($trakt_conf_file)->slurp);

  # В конфиге список шагов -- массив хешей. Чтобы оно сохряняло порядок
  # тут мы разделяем: массив для порядку, хеш, для соответсвия имени шага имени модуля...
  my $steps_old = $res->{steps};
  my $steps_new = {};
  my $steps_list = [];
  foreach my $el (@$steps_old)
  {
    my ($name) = keys %$el;  # имя первого попавшегося элемента хеша. Там должна быть одна пара.
    push @$steps_list, $name;
    $steps_new->{$name} = $el->{$name};
  }
  $res->{steps_list} = $steps_list;
  $res->{steps} = $steps_new;

  return $res;
}

sub conf_dir
{
  my $self = shift;
  my %opt = @_;

  return $self->_conf_dir($self->name, $self->trakt_path);
}

sub _conf_dir
{
  my $self = shift; # Метод может использоваться как метод класса, поэтому использовать нельзя
  my $trakt_name = shift;
  my $trakt_path = shift;

  $trakt_path = path($trakt_path || '.');

  # Относительный путь считается от местоположения запускаемой программы
  if ($trakt_path->is_relative)
  {
     $trakt_path = path($FindBin::Bin)->child($trakt_path);
  }
  return $trakt_path->child($trakt_name)->absolute;
}

# Это метод класса. Нужен для того чтобы подглядеть в конфиг до того как экземпляр класса создан
# Это нужно потому что конфиг может запросить создание тракта используя кастомный класс наследника.
# И мы должн будем узнать имя этого класса до создания экземпляра
sub peek_conf
{
  my $class = shift;
  my %opt = @_;

  my $trakt_name = $opt{name};
  my $trakt_path = $opt{trakt_path};

  my $conf_dir = _conf_dir(undef, $trakt_name, $trakt_path);
  my $trakt_conf_file = $conf_dir->child("trakt.conf");

  my $res = _read_trakt_conf(undef, $trakt_conf_file);

  return $res;
}

# Forced conf -- это кастомный конфиг который применяется поверх конфига штатного.
# Позволяет переопределить какие-то из значений конфигов тракта и шага во время текущего
# запуска

sub forced_conf_name
{
    my $self = shift;
    my $trakt_name = $self->name;

    my $res = $self->work_dir->child("$trakt_name.toml");
    return $res;
}

sub _read_forced_conf
{
    my $self = shift;

    my $name = $self->forced_conf_name;

    return {} unless $name->exists;

    return from_toml( $name->slurp_utf8 );
}

1;
