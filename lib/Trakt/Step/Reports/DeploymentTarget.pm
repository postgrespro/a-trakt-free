package Trakt::Step::Reports::DeploymentTarget;

use Moose::Role;

use JSON;
use Template;
use Path::Tiny;


around 'core_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

#  my $target = shift; # У нас тут цель суррогатная делаем одно и тоже вне зависимости от цели.

  my $trakt = $self->step->trakt;

  # Получаем переменные необходимые для отчета от каждого шага
  my $vars = {trakt => {name => $self->trakt->name}};

  foreach my $step  ($trakt->steps)
  {
    $vars->{$step}=$trakt->step($step)->report_vars;
  }
  $vars->{target}=$self->name;

  my $res_dir = path($self->step->trakt->res_dir);
  if ($self->name)
  {
    # Если именованная цель, то складываем результаты по директориям с соответсвующим именем
    $res_dir = $res_dir->child($self->name);
    $res_dir->mkpath();
  }

  my $report_md = $res_dir->child('report.md');
  my $report_html = $res_dir->child('report.html');

  $report_md->spew($self->tt_process($vars));
  $self->run_command('convert_report', "pandoc -f markdown $report_md > $report_html");

  my $cache_dir = $self->cache_dir;

  $cache_dir->mkpath();

  $cache_dir->child("raw_vars.dump.json")->spew(JSON->new->pretty->encode($vars));

  $self->$orig(@args)
};

sub tt_process
{
  my $self = shift;
  my $vars = shift;

  my $template_dir = $self->step->conf_dir."/tt";
  my $tt_name = 'main.tt';

  my $res = "";
  my $tt = Template->new({
      INCLUDE_PATH => $template_dir,
      INTERPOLATE  => 1,
  }) || die "$Template::ERROR\n";

  $tt->process($tt_name, $vars, \$res)
      || die $tt->error(), "\n";
  return $res;
}

around 'debdeps' => sub {
    my $orig = shift;
    my $self = shift;

    return ($self->$orig(@_), "pandoc");
};


1;
