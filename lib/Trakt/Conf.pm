package Trakt::Conf;

use strict;
use JSON;
use Path::Tiny;


sub new
{
  my $class = shift;
  my %opt = @_;
  my $trakt = $opt{trakt};
  my $cert_conf = $opt{cert_conf};
  my $trakt_name = $opt{trakt_name} || $trakt->name;
  my $conf_dir = Trakt::Conf->conf_dir(%opt);

  my $trakt_conf_file = $conf_dir->child("trakt.conf");

  my $json = JSON->new->relaxed;

  my $self = $json->decode(path($trakt_conf_file)->slurp);

  if (-d $conf_dir."/lib")
  {
    push @INC, $conf_dir."/lib";
  }
  # В конфиге список шагов -- массив хешей. Чтобы оно сохряняло порядок
  # тут мы разделяем: массив для порядку, хеш, для соответсвия имени шага имени модуля...

  my $steps_old = $self->{steps};
  my $steps_new = {};
  my $steps_list = [];
  foreach my $el (@$steps_old)
  {
    my ($name) = keys %$el;  # имя первого попавшегося элемента хеша. Там должна быть одна пара.
    push @$steps_list, $name;
    $steps_new->{$name} = $el->{$name};
  }
  $self->{steps_list} = $steps_list;
  $self->{steps} = $steps_new;

  if (defined $opt{branch})
  {
    $self->{branch} = $opt{branch};
  }
  $self->{trakt} = $trakt;
  if ($cert_conf)
  {
    $self->{cert} = $json->decode(path($cert_conf)->slurp);
  }

  bless $self, $class;
  return $self;
}

sub conf_dir
{
  my $self = shift;
  my %opt = @_;

  my $trakt_name;
  my $trakt_path;

  # Может вызыаться в двух вариантах, как метод объекта, и как метод класса. Во втором случае $self -- имя красса.
  if (ref $self)
  {
    $trakt_name = $self->{trakt}->name;
    $trakt_path = path($self->{trakt}->trakt_path || '.');
  } else
  {
    $trakt_name = $opt{trakt_name};
    $trakt_path = path($opt{trakt_path} || '.');
  }
  # Относительный путь считается от местоположения запускаемой программы
  if ($trakt_path->is_relative)
  {
     $trakt_path = path($FindBin::Bin)->child($trakt_path);
  }
  return $trakt_path->child($trakt_name)->absolute;
}

1;
