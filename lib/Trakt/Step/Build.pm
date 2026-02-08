package Trakt::Step::Build;

use Moose;
extends 'Trakt::Step';

with "Trakt::Step::Build::SelfReport";

1;


package Trakt::Step::Build::Target;

use Moose;
extends 'Trakt::Target';

with "Trakt::Step::Build::SelfReportTarget";

use SDL::Helling;
use SDL::Stapel::AFLpp::ReleaseSpec;

has version_prefixes => (is => 'rw',
                         isa  => 'ArrayRef[Str]',
                         default => sub { ['', 'std-', 'ent-', 'sdm-', 'REL_']});

# Директории из которых надо поствить патчи, находящиеся внутри src/patches
# Либо отдельное имя (чаще '.') либо ссылка на список имен,
# Либо особое имя '*' -- взять патчи из всех поддидеркторий src/patches, а так же все файлы в ней же
has patch_dirs => (is => 'rw', default=> '*');


### Методы которые следует переопределить в дочерних классах определяющие поведение сборки

# Основная роль реализующая исследование которое мы собираемся собирать.
# Одна или несколько
sub scrutiny_roles
{
  #  return "Local::Stapel::Postgres::FTapType";
}

# Директории которые должны быть наложены поверх кода
sub scrutiny_code_dirs
{
  my $self = shift;
  #  my @code_dirs = ($self->trakt->conf_dir->child('src/code')->absolute);
  #  return @code_dirs;
}

# Патчи которые должны быть наложены на код перед сборкой
sub get_patches
{
  my $self = shift;

  my $ranger = SDL::Ranges->new( prefixes => $self->version_prefixes );


  my $base_dir = $self->trakt->conf_dir->child('src/patches')->absolute;

  my @patch_dirs;
  if (ref $self->patch_dirs eq 'ARRAY')
  {
    @patch_dirs = @{$self->patch_dirs};
  }
  elsif ($self->patch_dirs ne '*')
  {
    @patch_dirs = $self->patch_dirs;
  } else
  {
    # Если patch_dirs -- звездочка (*)
    @patch_dirs = ('.');
    foreach my $file ($base_dir->children)
    {
      next unless $file->is_dir;
      push @patch_dirs, $file->basename;
    }
  }

  print "Подбираем патчи из комплекта в '$base_dir' которые следует наложить на дерево исходников:\n";

  my @patches = ();
  foreach my $dir (@patch_dirs)
  {
    print "Директория $dir\n";
    foreach my $file ($base_dir->child($dir)->children(qr/\.diff\z/))
    {
      print $file->basename(),": ";
      my $name = $file->basename('.diff');
      if (! ($name =~ /^.*\.(.*?)$/))
      {
        print "Нет вторичного суфикса. ACCEPTED\n";
        # Все файлы без вторичного суфикса просто добавляем
        push @patches, $file;
        next;
      }
      my $secondary_suffix = $1;
      if(! $ranger->validate($secondary_suffix))
      {
        print "Суфикс '$secondary_suffix' не по установленной схеме. Наверное не суфикс вовсе. ACCEPTED\n";
        push @patches, $file;
        next;
      }
      my $branch = $self->trakt->conf->{branch}; # FIXME пока так, а потом надо систему учета версий как-то переписать...
      my $version = $self->trakt->convoy->project_version_major;
      $branch =~ s/_STABLE$//; # REL_16_STABLE -> REL_16 FIXME
      if ($ranger->match($secondary_suffix, $version, $branch) )
      {
        print "ACCEPTED \n";
        push @patches, $file;
      } else
      {
        print "REJECTED\n";
      }
    }
  }
  return @patches;
}

# Роли задающие разные варианты сборки. Каждая цель шага сборки -- свой набор ролей.
sub build_flavours
{
  my $self = shift;
  my $build_name = shift;

  #  my $flavours = {
  #    afl      => ["SDL::Stapel::Flavour::AFLpp"],
  #    coverage => ["SDL::Stapel::Flavour::Coverage"],
  #  };
  #  die "Неизвестная сборка: '$build_name'" unless $flavours->{$build_name};
  #  return @{$flavours->{$build_name}};
}

#### А это уже методы класса которые универсально используют все то что настроенно выше

sub afl_stapel
{
  my $self = shift;

  die "afl_stapel следует вызывать только если цель у нас afl" if $self->name ne 'afl';
  my $afl_src_dir = $self->exchange_dir->child('afl_src');
  my $afl_build_dir = $self->exchange_dir->child('afl_build');
  my $afl_install_dir = $self->exchange_dir->child('afl_install');

  my $afl_rsp = SDL::Stapel::AFLpp::ReleaseSpec->new();
  my $afl_stapel = $self->trakt->helling->AFLpp(release_spec => $afl_rsp, install_dir => $afl_install_dir, build_dir => $afl_build_dir, src_dir => $afl_src_dir);

  return $afl_stapel;
}

sub stapel_init_args
{
  my $self = shift;

  my $src_dir = $self->exchange_dir->child('postgres_src'); # FIXME тут надо разобраться, для случая покрытия мы сорцы и директорию сборки должны не терять, поэтому exchange, а не cache. А для остальных случаев думать надо..
  my $build_dir = $self->exchange_dir->child('postgres_build');
  my $install_dir = $self->exchange_dir->child('postgres_install');
  my $pgdata_dir = $self->exchange_dir->child('postgres_data');

  my $res = {
    release_spec     => $self->trakt->rsp,
    install_dir      => $install_dir,
    build_dir        => $build_dir,
    src_dir          => $src_dir,
    context_data_dir => $pgdata_dir,
    patches          => [$self->get_patches],
    dirs             => [$self->scrutiny_code_dirs],
    extra_roles      => [$self->scrutiny_roles, $self->build_flavours($self->name)],
  };

  # initdb запускаем только для одной "дефолтной сборки" (она обычно afl)
  $res->{skip_context_setup} = 1 if $self->name ne $self->trakt->convoy->default_build;

  return $res;
}

sub stapel
{
  my $self = shift;

  my $stapel = $self->trakt->helling->postgres(%{$self->stapel_init_args()});

  if ($self->name eq 'afl') # FIXME это тоже надо переместить в stapel_init_args только подумать надо
  {
    $stapel->use_asan(1);
  }

  return $stapel;
}

around 'core_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  my $target_name = $self->name;
  my $step_name = $self->step->name;

  my $stapel = $self->stapel;
  if ($target_name eq 'afl')
  {
    my $prefix_stash = $self->witness_tag_prefix;
    $self->witness_tag_prefix('afl.');

    my $afl_stapel = $self->afl_stapel;
    $afl_stapel->build();

    $self->witness_tag_prefix($prefix_stash);

    $stapel->AFLpp_dir($afl_stapel->install_dir->child('bin')->absolute);
  }

  $stapel->build();

  $self->$orig(@args);
};

around 'debdeps' => sub {
    my $orig = shift;
    my $self = shift;

    return (
      $self->$orig(@_),
    );
};


1;
