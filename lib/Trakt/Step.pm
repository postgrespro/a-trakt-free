package Trakt::Step;

use strict;
use JSON;
use Path::Tiny;
use Module::Load;

use Moose;

has 'name' =>   (is => 'ro', required => 1);
has 'parent' => (is => 'ro', required => 1, weak_ref => 1);
has '_targets' => (is => 'rw', default => sub {return {}});
has '_exchange_dir' => (is => 'rw');
has '_cache_dir' => (is => 'rw');
has 'eternal' => (is => 'ro', required => 1, isa => 'Bool', default => 0);  # вечный шаг никогда не переходит в состояние done сам по себе.

with 'Trakt::CommandExecutorRole', 'Trakt::Role::SelfReport';

# самодельный конструктр. Нужен для того чтобы его можно было бы переопределить
# и запихнуть сюда фабрику объектов вместо штатного new, который может создавать только
# # объект титульного класса
sub create
{
  my $class = shift;
  my @args = @_;
  return "$class"->new(@args);
}

# по умолчанию генерируем имя модуля реализующего цель из имени текущего модуля
# добавляя ::Target
sub target_module
{
  my $self = shift;
  return ref($self)."::Target";
}

sub exchange_dir
{
  my $self = shift;
  my $value = shift;

  $self->_exchange_dir($value) if $value;
  return $self->_exchange_dir if $self->_exchange_dir;

  return $self->trakt->exchange_dir->child($self->name);
}

sub cache_dir
{
  my $self = shift;
  my $value = shift;

  $self->_cache_dir($value) if $value;
  return $self->_cache_dir if $self->_cache_dir;

  return $self->trakt->cache_dir->child($self->name);
}

sub res_dir
{
  my $self = shift;
  return path($self->trakt->res_dir."/".$self->name);
}

sub conf_dir
{
  my $self = shift;
  return path($self->trakt->conf_dir."/".$self->name);
}

sub done_flag
{
  my $self = shift;
  return $self->trakt->exchange_dir->child($self->name.".done");
}

sub conf
{
  my $self = shift;
  return  $self->{_conf} if defined $self->{_conf};

  my $config_name;

  if (-e $self->conf_dir."/config.json")
  {
     # новый вариант именования
     $config_name = $self->conf_dir."/config.json";
  }
  elsif (-e $self->conf_dir."/step.conf")
  {
    # старвый вариант именования. FIXME надо почистить
    $config_name = $self->conf_dir."/step.conf";
  } else
  {
    die "Config file for ".$self->conf_dir." step is not found (expecting '".$self->conf_dir."/config.json"."'.";
  }
  $self->{_conf} = decode_json(path($config_name)->slurp);
  return $self->{_conf};
}

sub target
{
  my $self = shift;
  my $name = shift;

  my $known_targets = $self->_targets;
  return $known_targets->{$name} if exists $known_targets->{$name};

  my $class_name = $self->target_module();
  if (! moudule_is_loaded($class_name))
  {
    load $class_name;
  }

  my $target = $class_name->new(parent => $self, name => $name);

  $known_targets->{$name} = $target;

  return $target;
}


sub targets
{
  my $self = shift;
  return $self->trakt->targets;
}


# Alias для parent
sub trakt
{
  my $self = shift;
  return $self->parent;
}


# early_run запускается для всех целей в момент запуска тракта
# Смысл этого вызова добавить туда всё интерактивное взаимодействие с пользователем которое может понадобиться шагу
# Спросить пароль от sudo и т.п.
# Добавлять сюда излишней функциональности не рекомендуется...
sub early_run
{

}

# Если не заоверрайжено, то последовательно запускаем все цели для этого шага.
# Если цели нет, то запускаем "суррогатную" единственную цель.
sub run
{
  my $self = shift;

  local $SDL::Trakt::Witness::Witness = $self; # Отвественным за фиксацию событий запуска назначем текущий объект

  my @targets = $self->targets;

  print "================ Running step: ".$self->name." ====================\n";
  if ($self->done_flag->exists)
  {
    print "Step already done, skiping...\n";
    return;
  }

  $self->before_run();

  foreach my $target_name (@targets)
  {
    $self->target($target_name)->run();
  }

  # Вызов inner() позволяет для метода run класса step использовать модификатор
  # augment (дополнение) в потомках класса step. Это позволит расширять функциональность
  # метода run в потомках, а контролировать запуск метода run из суперкласса step.
  inner();  # FIXME depricated! augment нельзя использовать в ролях. Нам это не нарвиться!

  $self->after_run();

  if (! $self->eternal)
  {
    $self->done_flag->touchpath;
  }

  # удаляем по-target'овые флаги так как пошаговый их перекрывает
  # и даже для "вечного шага удаляем" он просто перезапуститься тогда
  foreach my $target_name (@targets)
  {
    $self->target($target_name)->done_flag->remove;
  }
}

# Если хочется запустить что-то до того как начался запуск целей, переопределите этот метод
sub before_run
{
}

# Если хочется запустить что-то после того как завершился запуск целей, переопределите этот метод
sub after_run
{
}


sub report_vars
{
  my $self = shift;
  my @targets = $self->targets;

  if (@targets && $targets[0] eq '' &&  $#targets == 0)  # Если @targets == ('') т.е. у нас суррогатная пустая цель
  {
    my $target = $self->target('');
    return undef unless $target;
    return $target->report_vars();
  }

  my $res = {};
  foreach my $target_name (@targets)
  {
    my $report_vars = $self->target($target_name)->report_vars();
    $res->{target} ||= {};
    $res->{target}->{$target_name} = $report_vars if $report_vars;
  }
  return $res;
}

sub moudule_is_loaded
{
  my $name = shift;
  my %h = ();
  eval("%h = %".$name."::"); # не безопасно, но у нас все свои.
  die $@ if $@;

  return 1 if %h;
  return 0;
}

sub debdeps
{
  my $self = shift;
  my @res = ();

  my @targets = $self->targets;

  if (@targets)
  {
    # какие-то цели для шага таки заданы
    foreach my $target_name ($self->targets)
    {
      my $target = $self->target($target_name);
      push @res, $target->debdeps;
    }
  } else
  {
    # скорее всего у этого шага цели динамически определены, и они еще не готовы
    # в этом случае создадим ложную цель и получим зависимости от нее...
    my $fake_target = $self->target('fake_target');
    push @res, $fake_target->debdeps;
  }
  return @res;
}

1;
