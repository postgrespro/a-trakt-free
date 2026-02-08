package Trakt::Role::SelfReport;

use Moose::Role;
use utf8;
use JSON;

sub local_tt_process
{
  my $self = shift;
  my $template = shift;
  my $vars = $self->report_vars(); # FIXME должен ли этот метод оставаться в основном классе?

  $vars->{self} = $self;
  $vars->{JSON} = JSON->new->pretty; # Чтобы можно было пользоваться обектом JSON в шаблонах. FIXE: не уверен что это лучшее решение

  my $res = "";
  my $tt = Template->new({
#      INCLUDE_PATH => $template_dir,
      INTERPOLATE  => 1,
  }) || die "$Template::ERROR\n";

  $tt->process(\$template, $vars, \$res)
      || die $tt->error(), "\n";
  return $res;
}


# Наследники должны переопределить эту функцию, чтобы шаг мог сам сгенирировать фрагмент отчета на основании прикопанных значений.
sub self_report
{
  my $self = shift;
  my $name = shift;

  my $template = $self->get_tt($name);
  my $res = $self->local_tt_process($template);

  return $res;
}

1;
