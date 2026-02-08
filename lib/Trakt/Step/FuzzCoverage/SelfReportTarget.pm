package Trakt::Step::FuzzCoverage::SelfReportTarget;

use Moose::Role;
use utf8;



sub get_tt
{
  my $self = shift;
  my $name = shift // "main";

  die "Неизвестный шаблон '$name'" if $name ne "main";

  return "
[% commands.cleanup %]
[% commands.prepare %]
[% commands.process_samples %]
[% commands.generate_coverage %]
[% commands.saving_results %]

";
}



1;
