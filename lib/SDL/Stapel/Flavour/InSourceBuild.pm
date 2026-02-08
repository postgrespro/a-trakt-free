package SDL::Stapel::Flavour::InSourceBuild;

use Moose::Role;

# Это вообще атрибут, но мы его вот так вот форсим в единицу (has +attr в ролях почему-то не работает, переопределить дефолт не можем)
sub is_insource_build
{
  return 1;
}

1;
