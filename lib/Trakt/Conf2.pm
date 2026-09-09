package Trakt::Conf2;

use Moose::Role;
#use MooseX::RequiresClass;

#requires_class 'Trakt';

use JSON;
use Path::Tiny;

has "conf2" =>(is =>'rw', lazy => 1, builder => '_read_trakt_conf');
#has "_cert_conf_file" => (is => 'rw', isa => 'Path::Tiny');


around BUILDARGS => sub {
    my ($orig, $class, @args) = @_;
    my $res = $class->$orig(@args);

    #    $res->{_cert_conf_file} = path($res->{cert_conf}) if $res->{cert_conf};

    #    # delete $res->{cert_conf}; # FIXME потом зачищать чтобы не мешался

    return $res;
};

sub _read_trakt_conf
{
  my $self = shift;
  my $conf_dir = $self->conf_dir;

  my $trakt_conf_file = $conf_dir->child("trakt.conf");

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

  my $trakt_name;
  my $trakt_path;

  # Может вызыаться в двух вариантах, как метод объекта, и как метод класса. Во втором случае $self -- имя красса.
  $trakt_name = $self->name;
  $trakt_path = path($self->trakt_path || '.');

  # Относительный путь считается от местоположения запускаемой программы
  if ($trakt_path->is_relative)
  {
     $trakt_path = path($FindBin::Bin)->child($trakt_path);
  }
  return $trakt_path->child($trakt_name)->absolute;
}




1;
