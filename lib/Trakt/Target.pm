package Trakt::Target;

use strict;
use JSON;
use Path::Tiny;
use String::ShellQuote;

use Moose;

has 'name' =>   (is => 'ro', required => 1);
has 'parent' => (is => 'ro', required => 1, weak_ref => 1);
has '_exchange_dir' => (is => 'rw');
has '_cache_dir' => (is => 'rw');
has 'is_target'  => (is => 'ro', isa => 'Bool', default => 1);


with 'Trakt::CommandExecutorRole', 'Trakt::Role::SelfReport';

sub exchange_dir
{
  my $self = shift;
  my $value = shift;

  $self->_exchange_dir($value) if $value;
  return $self->_exchange_dir if $self->_exchange_dir;

  return $self->step->exchange_dir if $self->name eq ''; # Если цель пустая, то это вырожденный шаг из одной цели, и мы используем директории шага вместо директории цели

  return $self->step->exchange_dir->child($self->name);
}

sub cache_dir
{
  my $self = shift;
  my $value = shift;

  $self->_cache_dir($value) if $value;

  return $self->_cache_dir if $self->_cache_dir;

  return $self->step->cache_dir if $self->name eq ''; # Если цель пустая, то это вырожденный шаг из одной цели, и мы используем директории шага вместо директории цели

  return $self->step->cache_dir->child($self->name);
}

sub res_dir
{
  my $self = shift;
  return $self->trakt->res_dir->child($self->name);
}

sub done_flag
{
  my $self = shift;
  return $self->step->exchange_dir->child($self->name.".done");
}

# Человеко читаемый заголовок описывающий цель. Например для применения в отчетах
# Переопределяйте для потомков
# Должен быть в полноценных utf-8 символах, не байтах
sub title
{
  my $self = shift;
  {
    use utf8;
    return "[Заголовок по умолчанию для цели '".$self->name."' шага '".$self->step->name ."']";
  }
}

sub cleanup_cache
{
  my $self = shift;
  if (-e $self->cache_dir)
  {
    path($self->cache_dir)->remove_tree();
  }
}

sub cleanup_exchange
{
  my $self = shift;
  if (-e $self->exchange_dir)
  {
    path($self->exchanhe_dir)->remove_tree();
  }
}

sub cleanup
{
  my $self = shift;
  $self->cleanup_cache();
  $self->cleanup_exchange()
}

# Alisas для parent
sub step
{
  my $self = shift;
  return $self->parent;
}

sub trakt
{
  my $self = shift;
  return $self->parent->parent;
}

sub report_vars
{
  my $self = shift;
  my $report_dir;

  my $res = {};

  if ($self->name eq '')
  {
    $report_dir = $self->step->exchange_dir->child("reports");
  } else
  {
    $report_dir = $self->exchange_dir->child("reports");
  }

  # Ишем в $reoport_dir цели .json файлы и добавляем их в переменные для отчета
  if (-d $report_dir)
  {
    foreach my $file (path($report_dir)->children(qr/\.json$/))
    {
      my $base_name = $file->basename('.json');
      $res->{$base_name} = decode_json(path($file)->slurp);
    }
  }

  my $report_files_dir = $report_dir->child('files');
  if (-d $report_files_dir)
  {
    foreach my $file (path($report_files_dir)->children())
    {
      my $base_name = $file->basename();
      $res->{files}||={};
      $res->{files}->{$base_name} = {};
      $res->{files}->{$base_name} = path($file)->slurp;
    }
  }
  return $res;
}

sub stash_report_var
{
  my $self = shift;
  my $name = shift;
  my $value = shift;

  $self->{_report_vars_stash} ||= {};
  $self->{_report_vars_stash}->{$name}=$value;
}

# Запускает бианрник из директории bin.
# Либо "глобального" в корне всей системы трактов, либо внутри самого тракта.

sub exec_bin
{
  my $self = shift;
  my $tag = shift;
  my $bin = shift;
  my $args = shift || "";
  my $opts = shift || {};

  my $full_bin = $self->find_bin($bin);

  die "Executable '$bin' is not found" unless defined $full_bin;

  $self->run_command($tag, "$full_bin $args", $opts);
}

sub save_vars
{
  my $self = shift;
  my $report_dir;

  if ($self->name)
  {
    $report_dir = path($self->exchange_dir."/reports");
  } else
  {
    # Если имя цели пустое. то это "суррогатная" цель, и отчет надо складывать в step
    $report_dir = path($self->step->exchange_dir."/reports");
  }
  $report_dir->mkpath();
  $report_dir->child('vars.json')->spew(JSON->new->pretty->encode($self->{_report_vars_stash}));
}

sub report_file
{
  my $self = shift;
  my $file_name = path(shift);
  my $file_name_base = $file_name->basename;

  my $report_dir;

  if ($self->name)
  {
    $report_dir = path($self->exchange_dir."/reports");
  } else
  {
    # Если имя цели пустое. то это "суррогатная" цель, и отчет надо складывать в step
    $report_dir = path($self->step->exchange_dir."/reports");
  }
  $report_dir->child('files')->mkpath();
  $report_dir->child('files')->child($file_name_base)->spew_raw($file_name->slurp_raw());
}

sub save_result
{
  my $self = shift;
  my $src = shift;
  my $dst_name = shift;
  my $dst_dir = shift;

  $dst_name |= path($src)->basename;

  if ($dst_dir)
  {
    $dst_dir = path($self->step->trakt->res_dir)->child($dst_dir);
  } else
  {
    $dst_dir = path($self->step->trakt->res_dir);
    $dst_dir = $dst_dir->child($self->name) if ($self->name);
  }
  $dst_dir->mkpath;

  $self->run_command('save_results',"cp $src ".$dst_dir->child($dst_name));
#  path($src)->copy($dst_dir->child($dst_name));
}

sub debdeps
{
  return ();
}

# Этот метод переопределять и наследовать не следует расширяйте before_ core_ и after_
sub run
{
  my $self = shift;

  local $SDL::Trakt::Witness::Witness = $self; # Отвественным за фиксацию событий запуска назначем текущий объект

  print "---------------- Running step: ". $self->step->name." target: ". $self->name." --------------\n" if $self->name;
  if ($self->done_flag->exists)
  {
    print "Target already done, skiping...\n";
    return;
  }
  $self->before_run();
  $self->core_run();
  $self->after_run();
  $self->done_flag->touchpath;
}


sub before_run
{
  my $self = shift;
  # Поскольку класс Trakt::Target является атомарным, т.е. обязан отработать от
  # начала и до конца, то перед началом выполнения удаляем временные результаты
  # предыдущего запуска, т.е. cache_dir
  $self->cache_dir->remove_tree( { safe => 0 } );
}


sub core_run
{
  my $self = shift;
}

sub after_run
{
  my $self = shift;

  $self->save_vars() if $self->{_report_vars_stash};
}

# Этот метод следует использовать только для целей которые совпадаютс с целями тракта.
# FIXME как-то надо научиться ругаться в остальных случаях...
sub sklad
{
  my $self = shift;
  return $self->trakt->sklad($self->name);
}

1;
