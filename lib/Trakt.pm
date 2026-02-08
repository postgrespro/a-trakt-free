package Trakt;

use strict;
use Trakt::Conf;
use Trakt::Step;
use Trakt::Intendant;
use Trakt::Sklad;
use Path::Tiny;
use FindBin;
use Module::Load;
use SDL::SecretService;
use SDL::Stapel::Postgres::ReleaseSpec;

use Moose;

with 'Trakt::Conf2Role', 'Trakt::CommandExecutorRole';

has 'name' =>   (is => 'ro', required => 1);
has 'trakt_path' => (is => 'rw');
has 'branch' =>   (is => 'rw');
has 'cert_conf' => (is => 'rw');
has 'features' => (isa =>"ArrayRef[Str]", is => 'ro', default => sub{[]});


has 'convoy' => (is => 'rw', isa => 'Trakt::Convoy');
has 'intendant' => (is => 'rw', isa => 'Trakt::Intendant', default=> sub{my $self = shift; Trakt::Intendant->new(trakt=>$self)});
has '_sklads' => (is => 'ro', isa => 'HashRef[Trakt::Sklad]', default => sub{return {}});
has 'secret_service' => (is => 'rw', isa => 'SDL::SecretService', default => sub {return SDL::SecretService->new()} );

has '_helling_init_args' => (is => 'ro', isa => 'HashRef');
has 'helling' => (is => 'rw', isa => 'SDL::Helling', lazy => 1, default => sub {
  my $self = shift;
  my %args = %{$self->_helling_init_args || {}};

  $args{_sklad} //= $self->sklad->get('_helling');
  $args{secret_service} //= $self->secret_service;

  SDL::Helling->new(%args);
});  # "Ангар" для сборок

has 'rsp' => (is => 'rw', lazy => 1, default => sub {
  my $self = shift;
  SDL::Stapel::Postgres::ReleaseSpec->new(
      edition => $self->convoy->project_version_product,
      version => $self->convoy->project_version_major
    );
});

has 'work_dir' => (is => 'rw', default => sub{path('.')}); # рабочая директория тракта, в которой будут создаваться поддиректории с рабочими материалами и результатами


# Alias для self
sub trakt
{
  my $self = shift;
  return $self;
}

sub conf
{
  my $self = shift;
  $self->{_conf} ||= Trakt::Conf->new(trakt => $self, cert_conf => $self->cert_conf, branch => $self->branch, trakt_name => $self->name, trakt_path => $self->trakt_path); # FIXME сделать как-то более объектно ориентированно.
  return $self->{_conf};
}

sub conf_dir
{
  my $self = shift;
  return $self->{_conf}->conf_dir;
}

sub steps
{
  my $self = shift;
  return @{$self->conf->{steps_list}};
}

sub full_name
{
  my $self = shift;
  my $res = $self->name;

  # Формируем список включенных фич
  foreach (sort {$a cmp $b} @{$self->features})
  {
    $res .= ".+$_";
  }
  return $res;
}


# базовое имя для директорий внтури рабочей директории. В таком виде создаваться не будет, будет дополняться расширениями для получения разных типов директорий 
sub base_dir
{
  my $self = shift;
  my $new_value = shift;

  $self->{_base_dir} = $new_value if defined $new_value;
  $self->{_base_dir} //= $self->work_dir->child($self->full_name . "." . $self->conf->{branch});

  return path($self->{_base_dir});
}

# Директория в которой сохраняются данные которые могут быть востребованными другими шагами
sub exchange_dir
{
  my $self = shift;
  my $new_value = shift;

  $self->{_exchange_dir} = $new_value if defined $new_value;
  return $self->{_exchange_dir} if defined $self->{_exchange_dir};

  return  path($self->base_dir.".exch");
}

# Директория в которой сохраняются данные которые нужны только в процессе работы шага. По завершению работы шага директория может быть удалена
sub cache_dir
{
  my $self = shift;
  my $new_value = shift;

  $self->{cache_dir} = $new_value if defined $new_value;
  return $self->{cache_dir} if defined $self->{cache_dir};

  return  path($self->base_dir.".cache");
}

# Директория в окторую складываются результаты идущие в лабораторию
sub res_dir
{
  my $self = shift;
  my $new_value = shift;

  $self->{res_dir} = $new_value if defined $new_value;
  return path($self->{res_dir}) if defined $self->{res_dir};

  return path($self->base_dir.".res");
}

sub step
{
  my $self = shift;
  my $name = shift;

  $self->{_steps} ||= {}; # FIXME сделать как-то более объектно ориентированно

  unless (defined  $self->{_steps}->{$name})
  {
    my $class_name = $self->conf->{steps}->{$name};
    die "Step class name is not defined for step '$name'" unless defined $class_name;
    load $class_name;
    $self->{_steps}->{$name} = $class_name->create(parent => $self, name => $name);
  }
  return $self->{_steps}->{$name};
}

# Директория в кторой находится сам алабамский тракт

sub top_dir  # вот не уверен что имя хорошее, но пусть будет так....
{
  return path($INC{"Trakt.pm"})->parent->parent;
}


# этот метод запускается в самом начале, при запуске тракта и запускает early_run'ы для каждого шага.
# Позволяет подготовительную работу сделать...
sub early_run
{
  my $self = shift;
  foreach my $step_name ($self->steps)
  {
    $self->step($step_name)->early_run;
  }
}

sub run
{
  my $self = shift;

  local $SDL::Trakt::Witness::Witness = $self; # Отвественным за фиксацию событий запуска назначем текущий объект

  foreach my $step_name ($self->steps)
  {
    $self->step($step_name)->run;
  }
}

sub debdeps
{
  my $self = shift;
  my @res = ();
  foreach my $step_name ($self->steps)
  {
    my $step = $self->step($step_name);
    print "================ $step_name =============\n";
    my @l = $step->debdeps();
    push @res, @l;
  }
  return @res;
}


# Цели тракта. Могут быть заданы в конфиге. Могут быть переопределны при наследовании
# Могут быть получены из информации о "конвое"
# Некоторые шаги могут состоять из целей тракта. Некоторые нет
sub targets
{
  my $self = shift;

  my $forced_conf = $self->forced_conf;
  my @res = @{$self->conf->{targets}} if $self->conf->{targets};

  if (!@res)
  {
    if ($self->convoy)
    {
      my @targets = $self->convoy->targets;
      warn "Конвой вернул пустой список целей, это подозрительно" unless @targets;
      @res = @targets;
    } else
    {
      @res = '';
    }
  }
  if ($forced_conf->{trakt}->{selected_targets})
  {
    # Велено запускать только избранные цели...
    my %known_targets;
    map {$known_targets{$_} = 1} @res;
    my @new_targets = @{$forced_conf->{trakt}->{selected_targets}};
    foreach my $target (@new_targets)
    {
      my $forced_conf_name = $self->forced_conf_name;
      die "В конфиге '$forced_conf_name' велено запускать цель '$target', однако в тракте такой цели нет. Трусливо прекращаю работу." unless $known_targets{$target};
    }
    @res = @new_targets;
  }
  return @res;
}

# Встроенная "фабрика". Создает либо одноименный класс, либо, если велено в конфиге
# какой-то из классов наследников

sub create
{
  my $class = shift;
  my %opt = @_;
  my $trakt_name = $opt{name};

  my $conf = Trakt::Conf->new(trakt_name => $trakt_name, trakt_path => $opt{trakt_path});

  my $class_name = $conf->{trakt_class};

  if(! defined $class_name)
  {
    # используем дефолтный класс тракта: Trakt
    return $class->new(@_);
  }

  if (! moudule_is_loaded($class_name))
  {
    load $class_name;
  }
  return $class_name->new(%opt);
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

sub BUILDARGS
{
  my $class = shift;
  my $args = @_==1 ? $_[0] : {@_};  # Берем параметры и из ссылки на хеш и из хеша

  if ($args->{tarball})
  {
    my $release_spec = undef;
    eval { $release_spec = SDL::Stapel::Postgres::ReleaseSpec->new(tarball_file => $args->{tarball});};

    die $@ if $@ && ! $args->{branch}; # Если нам не сказали что за версия а из тарбола она оже не добылась, то ругаемся и умираем
    if ($@ && $args->{branch})
    {
      print "Имя фйла с исходниками '".path($args->{tarball})->basename."' не соответсвует спецификации. Для определения версии и редакции используем предоставленное имя ветки '".$args->{branch}."' Пожалуйста проследите чтобы имя ветки и версия исходников совпадали, иначе возможна некорректная работа\n";
    }

    if ($release_spec && $args->{branch})
    {
      my $arg_b = $args->{branch};
      my $tar_b = $release_spec->branch;
      die "Переданное в параметрах имя ветки '$arg_b' отличается от имени ветки полученного из имени архива: '$tar_b'" if $arg_b ne $tar_b;
    }

    $args->{rsp} = $release_spec if $release_spec;
    $args->{branch} = $release_spec->branch;

    # Вот тут вот может случиться неудобняк, если в качестве хеллинга передали готовый объект. Но пока скажем "а вы так не делайте", а потом подумаем как делать, если понадобиться.
    $args->{helling} //= {};
    $args->{helling}->{postgres} //= {};
    $args->{helling}->{postgres}->{src_origin_class} = 'SDL::Stapel::Postgres::SrcOrigin::TarBall';
    $args->{helling}->{postgres}->{src_origin} //= {};
    $args->{helling}->{postgres}->{src_origin}->{file} = $args->{tarball};

  }

  # Если нам в helling вместо объекта передали хеш, то используем его для инициализации объекта
  $args->{_helling_init_args} = $args->{helling} if ref $args->{helling} eq 'HASH';
  delete $args->{helling} if ref $args->{helling} eq 'HASH';

  return $args;
}

sub BUILD
{
  my $self = shift;
  my $convoy_class = $self->conf->{convoy_class};
  my $intendant_class = $self->conf->{intendant_class};

  if (defined $convoy_class)
  {
    if (! moudule_is_loaded($convoy_class))
    {
      load $convoy_class;
    }
    $self->convoy($convoy_class->new(trakt => $self));
  }

  if (defined $intendant_class)
  {
    if (! moudule_is_loaded($intendant_class))
    {
      load $intendant_class;
    }
    $self->intendant($intendant_class->new(trakt => $self));
  }


  my $features_available = $self->conf->{features_available};
  $features_available = {map {$_ => 1} @$features_available};

  my $is_ok = 1;
  foreach (@{$self->features})
  {
    next if $features_available->{$_};
    warn "Feature '$_' is not available in ".$self->name;
    $is_ok = 0;
  }
  die "Some features are not available" unless $is_ok;

  $self->early_run;
}

sub sklad
{
  my $self = shift;
  my $name = shift;
  $name = "_" unless defined $name;
  $self->_sklads->{$name} ||= Trakt::Sklad->new(trakt=>$self, name => $name); # Если нет такого склада, то создаем его
  return $self->_sklads->{$name};
}

sub has_feature
{
  my $self = shift;
  my $name = shift;
  foreach (@{$self->features})
  {
    return 1 if $_ eq $name;
  }
  return 0;
}

1;
