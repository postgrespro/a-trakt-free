package SDL::Stapel::SrcOrigin;

use Moose;
use Path::Tiny;

# Мы от нашего "эллинга" используем склад, чтобы припрятывать склонированные репозитории
has 'helling' => ( is => 'rw', isa => 'SDL::Helling', required => 1, weak_ref => 1 );

# Описние "какие исходники берем". Интерпретация зависит от конкретного класса
# Может быть имя ветки в git, может быть путь tgz-файлу
has 'origin_spec' => (is => 'rw');



# Классы реализующие git- и tarball- источники исходников.
has _git_class => (is => 'ro');
has _tarball_class => (is => 'ro');


# Оборачивать метод new не рекомендуется Moose, но нам тут надо породить один
# из классов потомков, а не базовый класс. Поэтому немного нарушим, с малой
# потерей производительности.
around new => sub {
  my ($orig, $class, @args) = @_;

  if ($class eq __PACKAGE__) # Если мы не в потомке
  {
    $class = $class->choose_ancestor(@args);
    return $class->new(@args);
  }
  return $class->$orig(@args)
};

# По переданным аргументам определяет экземпляр какого наследника класса мы на
# самом деле будем создавать. Можно переопределить если вы знаете больше
sub choose_ancestor
{
  my $class = shift;
  my %args = @_;

  my $origin_spec = $args{origin_spec};

  die "Не задан спецификатор источника исходников (обычно имя ветки или путь к tarball'у)" unless $origin_spec;

  if (path($origin_spec)->exists)
  {
    die "Не задан класс работы с истоником исходников tarball (_tarball_class) при наличии самого tarball" unless defined $args{_tarball_class};
    return $args{_tarball_class};
  }

  die "Не задан класс работы с истоником исходников git (_git_class) при том что спецификатор вероятно имя ветки" unless defined $args{_git_class};
  return $args{_git_class};
}

sub get_sources
{
  #my $self = shift;
  #my $release_spec = shift;
  #my $res_dir = shift;

  # Реализовать в наследнках

}

# Так как у нас метод new обернут around, мы его "инлайнить" не сможем
# это скажется на производительности но у нас производство таких экземпляров
# не массовое.
# На будущее, правильное make_immutable тут делается так:
#__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
