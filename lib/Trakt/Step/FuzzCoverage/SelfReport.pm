package Trakt::Step::FuzzCoverage::SelfReport;

use Moose::Role;
use utf8;

sub get_tt
{
  my $self = shift;
  my $name = shift // "main";

  die "Неизвестный шаблон '$name'" unless $name eq 'main';

  return "
[% target_name = self.targets.0 -%]
## Построеение покрытия на примере цели `[% target_name %]`

[% self.target(target_name).self_report %]

  ";



}



1;
