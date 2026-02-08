package Trakt::Step::Build::SelfReportTarget;

use Moose::Role;
use utf8;


sub postgres_build_tt
{
  return "

### [% self.title %]

[% IF commands.item('afl.compile') %]

[% self.self_report('afl') %]

#### Собственно сборка Postgres

[% END %]

##### Получение и подготовка исходников

```
[% commands.git_get_src %]

[% commands.prepare_src %]
```

##### Конфигурирование и компиляция

```
[% commands.configure %]

[% commands.compile %]
```

##### Установка

```
[% commands.install %]
```

##### Создание экземпляра хранилища Postgres
[% IF self.trakt.convoy.default_build == self.name %]
```
[% commands.context_setup %]
```
[% ELSE %]
Для второстепенной сборки инициализация директории с данными не производится
[% END %]
";
}


sub afl_build_tt
{
  return "
##### Сборка и установка фаззера AFL++

###### Получение и подготовка исходников

```
[% commands.item('afl.git_get_src') %]

[% commands.item('afl.prepare_src') %]
```

###### Конфигурирование и компиляция

```
[% commands.item('afl.configure') %]

[% commands.item('afl.compile') %]
```

###### Установка

```
[% commands.item('afl.install') %]
```
";
}


sub get_tt
{
  my $self = shift;
  my $name = shift // "postgres";

  return $self->postgres_build_tt if $name eq 'postgres';
  return $self->afl_build_tt      if $name eq 'afl';

  die "Неизвестный шаблон '$name'";
}



1;
