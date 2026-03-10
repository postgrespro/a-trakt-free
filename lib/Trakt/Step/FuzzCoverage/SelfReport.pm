package Trakt::Step::FuzzCoverage::SelfReport;

use Moose::Role;
use utf8;

sub get_tt
{
  my $self = shift;
  my $name = shift // "main";

  die "Неизвестный шаблон '$name'" unless $name eq 'main';

  return "
[% IF self.targets.0 %] [%# Вернули ли нам список или скаляр %]
  [% target_name = self.targets.0 %]
[% ELSE %]
  [% target_name = self.targets %]
[% END %]
## Построеение покрытия на примере цели `[% target_name %]`

[% self.target(target_name).self_report %]

  ";



}



1;
