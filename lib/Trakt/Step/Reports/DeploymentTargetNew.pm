package Trakt::Step::Reports::DeploymentTargetNew;

use Moose::Role;

use JSON;
use Template;
use Path::Tiny;


around 'core_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  my $trakt = $self->trakt;
  my $vars = {};

  $vars->{trakt} = $trakt;

  my $res_dir = $trakt->res_dir;

  my $report_md = $res_dir->child('report.md');
  my $report_html = $res_dir->child('report.html');

  $report_md->spew_utf8($self->tt_process($vars));
  $self->run_command('convert_report', "pandoc -f markdown_strict -t html $report_md > $report_html");

  $self->$orig(@args)
};

around 'debdeps' => sub {
    my $orig = shift;
    my $self = shift;
};

sub tt_process
{
  my $self = shift;
  my $vars = shift;

  my $template_dir = $self->step->conf_dir->child("tt");
  my $tt_name = 'main.tt';

  my $res;
  my $tt = Template->new({
      INCLUDE_PATH => $template_dir,
      INTERPOLATE  => 1,
  }) || die "$Template::ERROR\n";

  $tt->process($tt_name, $vars, \$res)
      || die $tt->error(), "\n";
  return $res;
}


1;
