package Trakt::Step::ShowReports;

use Moose;
use Path::Tiny;
use String::ShellQuote;

extends 'Trakt::Step';

has '+eternal' => (default => 1); # Этот шаг не будет создавать .done файла и будет запукаться всегда

around 'debdeps' => sub {
    my $orig = shift;
    my $self = shift;

    return ($self->$orig(@_), "elinks");
};

# Поскольку шаг ShowSummary ничего не делает с целями тракта, то метод targets
# шага возвращает пустой список и методы run целей тракта не будут запускаться.
override 'targets' => sub
{
  return ();
};

# Метод augment вызывается из родительского метода при помощи вызова inner()
augment 'run' => sub
{
  my $self = shift;

  # для доступа к целям тракта обращаемся непосредственно к тракту, поскольку
  # в шаге Summary метод targets возвращает пустой список.
  my @targets = $self->trakt->targets;

  my $any_target = $targets[0];

  my $cache_dir = $self->cache_dir;
  $self->cache_dir->mkpath();
  my $pipe_file = $self->cache_dir->child("tmux_runner.pipe");
  my $runner_commands_log = $self->cache_dir->child("tmux_runner.commands.log");
  my $paner_log = $self->cache_dir->child("tmux_runner.paner.log");
  path($self->cache_dir())->mkpath;
  my $runner_conf_file = path($self->cache_dir())->child("tmux_runner.conf");

  my $summary_file = $self->trakt->res_dir->child("summary");
  my $report_file = $self->trakt->res_dir->child("report.html");
  $report_file = $self->target($any_target)->res_dir()->child("report.html") unless $report_file->exists; # Пробуем смотреть отчет по старому, если по новому его нет. FIXME следует удалить вместе с unit-based трактами
  my $lcovclip_file = $self->trakt->res_dir->child('coverage_clipped_total.html');


  my $panes = [];

  push @$panes, { summary       => { name => 'summary',  command => "less -R $summary_file" }} if $summary_file->exists;
  push @$panes, { report_html   => { name => 'report',   command => "elinks $report_file"   }} if $report_file->exists;
  push @$panes, { lcovclip_html => { name => 'lcovclip', command => "elinks -dump-color-mode 3 -dump -dump-width 300 $lcovclip_file | less -R -S"}} if $lcovclip_file->exists;

  my $runner_conf = {
      panes => $panes,
      triggers => {},
      "command-pipe" => "$pipe_file",
      "commands-log" => "$runner_commands_log",
      "paner-log" => "$paner_log",
  };

  $runner_conf_file->spew(JSON->new->pretty->encode($runner_conf));

  my $runner_bin = $self->trakt->find_bin('tmux_runner.pl');
  my $runner_bin_sq = shell_quote($runner_bin);
  my $runner_conf_file_sq = shell_quote($runner_conf_file);

  my $tmux_command = "tmux new-session -s tmux_runner_tmp \"bash -c '$runner_bin_sq $runner_conf_file_sq' 2>&1 >$cache_dir/tmux_runner.log \" 2>&1 >$cache_dir/tmux.log";

  $self->run_command('tmux_runner', "$tmux_command");
};

around 'debdeps' => sub {
    my $orig = shift;
    my $self = shift;

    return ($self->$orig(@_), qw(elinks));
};

1;


package Trakt::Step::ShowReports::Target;

use Moose;
extends 'Trakt::Target';

1;
