package Trakt::Step::Build::SelfReport;

use Moose::Role;
use utf8;

sub get_tt
{
  my $self = shift;
  my $name = shift // "main";

  die "Неизвестный шаблон '$name'" unless $name eq 'main';

  # FIXME тут надо не перечислять вручную а цикл сделать. Но непонятно как правильно сделать нужную сборку первой (AFL++) поэтому пока перечисляем явноё
  return "
## Сборка

  [% self.target('afl').self_report %]

  [% self.target('coverage').self_report %]

  ";

}



1;
