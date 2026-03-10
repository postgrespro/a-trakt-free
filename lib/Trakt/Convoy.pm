package Trakt::Convoy;

use Moose;

use String::ShellQuote;

has 'trakt' => (is => 'ro', required => 1, isa => "Trakt");
has 'default_build' => (is => 'rw', default => "none"); # Сборка по умолчанию, если делаются какие-то информационные запросы общего характера к исследуемой программе (например получить список целей), то делаются они именно к этому варианту сборки. Должно быть переопределено.


# Заготовка которая должна быть переопределена
# Функция которая возвращает поногое (или относительное) имя бинарника исследуемой программы в заданой сборке
# FIXME библиотека она вообще тоже binary. Правильно executable. Но тут все равно все надо переделывать.
sub binary
{
  my $self = shift;
  my $build_name = shift;
  my $target_name = shift; # Бывает так что у нас отдельный бинарник для каждой цели
  # return "build/$build_name/install/my_cool_executable
  die "This function must be overridden!"
}

# Этот метод должен возвращать ссылку на список путей по которым будут искаться подгружаемые библиотеки
# Этот метод должен быть переопределен если вы хотите подгружать хоть какие-то библиотеки
sub lib_dirs
{
  my $self = shift;
  my $build_name = shift;

  my $build_target = $self->trakt->step('build')->target($build_name);
  my $lib_dir = $build_target->stapel->install_dir->child("lib")->absolute;

  # return ["$root/build/$build_name/install/lib"]
  die "This function should be overridden!"
}


# Этот метод должен возвращать имена (без путей) библиотек которые должны быть подгружены при запуске цели
# библиотеки с этими именами будут искаться среди путей возвращаемых методом lib_dirs и подгржуаться посредством
# LD_PRELOAD или AFL_PRELOAD при запуске цели или фаззинга цели.
# Этот метод следует переопределить, если вам надо подгружать какие-то библиотеки.
sub preload_libs
{
  my $self = shift;
  my $target_name = shift; # На случай если как-то зависит от имени цели

  # Переопределите если надо что-то подгружать.
  # return ['libexample.so', 'libcool.so'];
  return [];
}


# Этот метод возвращает сткроку со списком всех подгружаемых библиотек пригодную для подстановки
# в переменную окружения LD_PRELOAD или ADL_PRELOAD в shell-команде
# Эту фнункцию переопределять в норме не надо.
sub preload_lib_env
{
  my $self = shift;
  my $build_name = shift;
  my $target_name = shift; # на случай если зависит от выбранной цели

  my $res = '';
  my $libs = $self->preload_libs($target_name);
  foreach my $lib (@$libs)
  {
    my $is_found = 0;
    foreach my $path (@{$self->lib_dirs($build_name, $target_name)})
    {
      my $file = $path->child($lib);
      if ($file->exists)
      {
        $is_found = 1;
        $res .= ":" if $res;
        $res .= shell_quote($file);
      }
      die "Library '$lib' not found" unless $is_found;
    }
  }
  return $res;
}


# Заготовка которая должна быть переопределена
# Функция которая возвращает команду которая заупстит бинарник исследуемой программы в заданной сборке, с заданной целью, с заданными входными данными
sub command
{
  my $self = shift;
  my $build_name = shift;
  my $target = shift;
  my $sample = shift;
#  return $self->binary($build_name)." --do-it-mazefaka $target $sample";
  die "This function should be overridden!"
}


# Команда которую следует запускать для инициализации контекста (в первую очередь дискового) исследуемой программы
sub instance_init_command
{
  my $self = shift;
  my $storage_path = shift;
  my $instance_name = shift;

  # return "kill -9 -1"; # Начинаем жизнь с чистого листа

  return undef;
}


# Переменные окружения которые следует установить при запуске инстанса
sub instance_env
{
  my $self = shift;
  my $storage_path = shift;  # FIXME вот как-то оно должно косвенно из какого-то контекста брать storaget_path для текущего шага, но пока не понимаю как...
  my $instance_name = shift;

  #my $res = {AAA => "bbbb.$instance_name", CCC => "$storage_path/$instance_name"};
  return {};
}

# Переменные окружения которые следует установить при запуске инстанса в формате строки
sub instance_env_str
{
  my $self = shift;
  my $storage_path = shift;  # FIXME вот как-то оно должно косвенно из какого-то контекста брать storaget_path для текущего шага, но пока не понимаю как...
  my $instance_name = shift;
  my $extra_env = shift // {}; # Дополнительные опции которые пользователь хочет добавить в строку

  my $env = $self->instance_env($storage_path, $instance_name);
  $env = {%$env, %$extra_env};

  my $res = "";
  foreach my $key (keys %$env)
  {
    $res .= " "  if $res;
    $res .= "$key=" . shell_quote($env->{$key});
  }
  return $res;
}

# Определяем мажорную версию исследуемого проекта.
# Пока исходя из имени ветки. Позже надо будет выковыривать из процедуры сборки
sub project_version_major
{
  my $self = shift;
  my $trakt = $self->trakt;

  my $branch = $trakt->conf->{branch};

  return 14 if $branch eq 'shardman';
  return 14 if $branch eq 'shardman-dev';
  return 16 if $branch eq 'master';

  if ($branch =~/^REL_(\d\d)/)
  {
    return $1;
  }
  if ($branch =~/^(std|ent|sdm)-(\d+)$/)
  {
    return $2;
  } else
  {
    die "Не могу определить версию из имени ветки '$branch'";
  }
}

sub project_version_product
{
  my $self = shift;
  my $trakt = $self->trakt;

  my $branch = $trakt->conf->{branch};

  return 'shardman' if $branch eq 'shardman';
  return 'shardman' if $branch eq 'shardman-dev';
  return 'vanilla' if $branch eq 'master';
  return 'vanilla' if $branch =~/^REL_(\d\d)/;

  if ($branch =~/^(std|ent|sdm)-(\d+)(-cert|)$/)
  {
    return $1
  } else
  {
    die "Не могу найти код продукта в имени ветки '$branch'";
  }
}

# Человекочитаемое название проекта
sub project_title
{
  my $self = shift;
  my $code_name = $self->project_version_product;

  return "Postgres Pro Standart" if $code_name eq 'std';
  return "Postgres Pro Enterptise" if $code_name eq 'ent';
  return "Postgres Pro Shardman" if $code_name eq 'sdm' || $code_name eq 'shardman';
  return "PostgreSQL" if $code_name eq 'vanilla';

  die "Неизвестный продукт с кодовым именеи '$code_name'";
}


# В базе у тракта нет целей. Конкретная реализация конвоя должена переопределить эту функцию, и возвращать цели
# которые должны быть у тракта
sub targets
{
  return '';
}

# Позволяет нам сохранить срабатывание для воспроизведения на обычном, не порченном магией и чародейством продукте
# и передать его разработчикам. Конкретная реализация конвоя должна переопределить эту функцию.
sub dump_reproducer_command
{
  return;
}

# Список бинарников (исполняемых и библиотек) которые были вообще затронуты в процессе фаззинга
# В первую очередь для построения покрытия. Может еще для чего-то.
# В норме не переопределяется
sub affected_binaries
{
  my $self = shift;
  my $build_name = shift;
  my $target_name = shift;

  my $res = [$self->binary($build_name, $target_name)];

  # FIXME этот цикл почти дублирует код из preload_lib_env надо как-то объединить умно
  my $libs = $self->preload_libs($target_name);
  foreach my $lib (@$libs)
  {
    my $is_found = 0;
    foreach my $path (@{$self->lib_dirs($build_name, $target_name)})
    {
      my $file = $path->child($lib);
      if ($file->exists)
      {
        $is_found = 1;
        push @$res, $file;
      }
      die "Library '$lib' not found" unless $is_found;
    }
  }
  return $res;
}

1;
