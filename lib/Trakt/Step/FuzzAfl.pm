package Trakt::Step::FuzzAfl;

# Временная копия чтобы раньше времени не ломать фаззинг сетевого пакетра от Trakt::Common::FuzzAfl зависящего

use Moose;
extends 'Trakt::Step';

with "Trakt::Step::FuzzAfl::SelfReport";


around 'report_vars' => sub {
    my $orig = shift;
    my $self = shift;

    my $res = $self->$orig(@_);

    $res->{conf}={afl=>{}};

    return $res;
};

before early_run => sub {
  `grep 0 /proc/sys/kernel/randomize_va_space || sudo sh -c 'echo 0 >/proc/sys/kernel/randomize_va_space'`;
};


# ########################################

package Trakt::Step::FuzzAfl::Target;

use Moose;
extends 'Trakt::Target';
with "Trakt::Step::FuzzAfl::SelfReportTarget";

use Path::Tiny;
use String::ShellQuote;
use JSON;

sub afl_env
{
  return"";
}

sub afl_extra_options
{
  my $self = shift;

  return "";
}

sub afl_limits_config
{
    my $self = shift;

    my $cfg  = $self->cache_dir->child('watch_dog.conf');
    my $json = JSON->new->pretty(1)->encode( $self->modify_watchdog_limits );
    $cfg->spew( $json );

    return $cfg;
}

sub modify_watchdog_limits {
    my ( $self ) = @_;

    my %default_limits_watchdog = $self->read_watchdog_default_limits;

    my %limits;

    foreach my $def_limit ( keys %default_limits_watchdog )
    {
      if (
        ref $self->trakt->forced_conf->{fuzz_afl} eq 'HASH'
        && $self->trakt->forced_conf->{fuzz_afl}->{watch_dog}->{limits}->{$def_limit}
      ) {
        $limits{limits}{$def_limit} = $self->trakt->forced_conf->{fuzz_afl}->{watch_dog}->{limits}->{$def_limit};
      } else {
        $limits{limits}{$def_limit} = $default_limits_watchdog{$def_limit};
      }
    }

    return \%limits;
}

sub read_watchdog_default_limits
{
    my $self = shift;

    my $json = JSON->new->relaxed;
    my $conf = $json->decode( path( $self->trakt->conf_dir->child('fuzz_afl')->child( 'watch_dog.conf' ) )->slurp );

    my %limits;

    foreach my $key ( keys %{$conf->{limits}} )
    {
        $limits{$key} = $conf->{limits}->{$key};
    }

    return %limits;
}

around 'before_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  my $res = $self->$orig(@args);

  $self->cache_dir->mkpath();

  my $binary_name = path($self->trakt->convoy->binary('afl', $self->name))->basename;
  $self->run_command('dead_checking', "killall -9 $binary_name; true");


  return $res;
};

sub afl_runner_conf
{
  my $self = shift;

  my $trakt_short_name = $self->trakt->name;
  $trakt_short_name =~ s/^fuzzing\.unit-based\.//;
  my ($targets_count, $target_n);
  {
    my @targets = $self->step->targets;
    $targets_count = int(@targets);
    $target_n = 0;
    foreach (@targets)
    {
      $target_n++;
      last if $self->name eq $_;
    }
  }

  my $branch_name = $self->trakt->branch;
  my $target_name = $self->name;

  my $afl_bin = $self->trakt->intendant->AFLpp->binary('afl-fuzz');

  my $in_dir = $self->sklad->samples->get;
  my $out_dir = $self->cache_dir->child('out');

  my $target_command = $self->trakt->convoy->command('afl',$self->name,'@@');
  my $nproc = $self->trakt->intendant->nproc;
  my $storage_init_command = $self->trakt->convoy->instance_init_command($self->cache_dir->child('storage'), '@INSTANCE_NAME@');
  my $instance_env = $self->trakt->convoy->instance_env($self->cache_dir->child('storage'), '@INSTANCE_NAME@');

  my $afl_runner_options = {
    fuzzer  => "$afl_bin",
    env     =>{AFL_MAP_SIZE=>880000, ASAN_OPTIONS => "detect_leaks=0:abort_on_error=1:symbolize=0", %{$instance_env}},
    options => "-i $in_dir -o $out_dir -t 1000 ",
    command => $target_command,
    banner  => "$branch_name:$trakt_short_name $target_name $target_n/$targets_count",
    masters => 1,
    slaves  => ($nproc - 1),
  };

  $afl_runner_options->{storage_init} = $storage_init_command if $storage_init_command;

  return $afl_runner_options;
}

sub tmux_runner_conf
{
  my $self = shift;

  my $target_name = $self->name;

  my $master_instanse_name = "M"; #FIXME как-то узнавать имя основного процесса фаззинга из скрипта запуска. Хардкодить не правильно

  my $cache_dir = $self->cache_dir;
  my $out_dir = $cache_dir->child('out');

  my $afl_start_script = $self->find_bin('run_aflpp_swarm.pl');
  $self->report_file($afl_start_script);

  my $pipe_file = $self->cache_dir->child("tmux_runner.pipe");
  my $runner_commands_log = $self->cache_dir->child("tmux_runner.commands.log");
  my $paner_log = $self->cache_dir->child("tmux_runner.paner.log");

  my $afl_runner_options = $self->afl_runner_conf();

  my $afl_runner_conf = $self->cache_dir->child('afl_runner.conf');
  $afl_runner_conf->spew(JSON->new->pretty->encode($afl_runner_options));

  my $runner_env = $self->afl_env();
  my $afl_extra_options = $self->afl_extra_options();

  my $afl_command = "$runner_env $afl_start_script $afl_runner_conf";

  my $watchdog_command = $self->find_bin('afl_watch_dog.pl')." ".
                                          shell_quote($self->afl_limits_config)." ".
                                          shell_quote($out_dir->child("$master_instanse_name/fuzzer_stats")). " ". shell_quote($pipe_file);
  my $runner_conf = {
    panes => [
      {fuzzer   => { name => 'fuzzer',   command => $afl_command,  log => "$cache_dir/fuzzer.log", capture => "$cache_dir/afl_ui"}},
      {top      => { name => 'top',      command => 'top'          }},
      {date     => { name => 'date',     command => 'watch date'   }},
      {watchdog => { name => "watchdog-$target_name", command => "watch $watchdog_command"}},
    ],
    triggers =>
      { STOP_FUZZER  => { command       => 'pkill -9 afl-fuzz'}, # Недостаточно изящно, но дело свое делает
        FINISH       => { pipe_commands => ["CAPTURE fuzzer", "CAPTURE fuzzer ascii", "EXIT_SOFT"]},
        EXIT_SOFT    => { pipe_commands => ["SET_TRIGGER pane-exited fuzzer KILL_ALL","STOP_FUZZER"]},
      },
    "command-pipe" => "$pipe_file",
    "commands-log" => "$runner_commands_log",
    "paner-log" => "$paner_log",
  };

  return $runner_conf;
}

around 'core_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  my $step_name = $self->step->name;
  my $target_name = $self->name;

  my $exch_dir = $self->exchange_dir;
  my $cache_dir = $self->cache_dir;
  my $res_dir = $self->trakt->res_dir->child($target_name);

  my $in_dir = $self->sklad->samples->get;
  my $out_dir = $cache_dir->child('out');

  die "Директория с сэмплами '$in_dir' не существует" unless -d $in_dir;

  if (-e "$res_dir/afl_ui.ascii")
  {
    print "Цель $target_name уже была успешно запущена, пропускаю\n";
    return 1;
  }

  my $runner_conf = $self->tmux_runner_conf;
  my $runner_bin = $self->find_bin('tmux_runner.pl');
  my $runner_bin_sq = shell_quote($runner_bin);
  $self->cache_dir()->mkpath;
  my $runner_conf_file = path($self->cache_dir())->child("tmux_runner.conf");
  $runner_conf_file->spew(JSON->new->pretty->encode($runner_conf));
  my $runner_conf_file_sq = shell_quote($runner_conf_file);


  my $tmux_command = "tmux new-session \"bash -c '$runner_bin_sq $runner_conf_file_sq' 2>&1 >$cache_dir/tmux_runner.log \" 2>&1 >$cache_dir/tmux.log";

  $self->run_command('run_fuzzing', "$tmux_command");

  unless( -e "$cache_dir/afl_ui.ascii")
  {
    print "Судя по всему либо вышли вручную, либо упали в процессе работы. В обоих случаях дальнешую работу прекращаем";
    $self->after_run(); # убираем за собой в любом случае
    die;
  }

  my $master_instanse_name = "M"; #FIXME как-то узнавать имя основного процесса фаззинга из скрипта запуска. Хардкодить не правильно

  $res_dir->mkpath();
  $self->run_command('prepare_res', "cp $cache_dir/afl_ui.ascii $cache_dir/afl_ui.txt $res_dir");
  $self->run_command('prepare_res', "cat $res_dir/afl_ui.ascii | aha > $res_dir/afl_ui.html");
  $self->run_command('prepare_res', "mkdir -p $res_dir/samples");
  $self->run_command('prepare_res', "cp $out_dir/$master_instanse_name/queue/* $res_dir/samples");
  $self->run_command('prepare_res', "cp -r $out_dir/$master_instanse_name/crashes/ $res_dir");
  $self->run_command('prepare_res', "cp -r $out_dir/$master_instanse_name/hangs/ $res_dir");

  # сохраняем $runner_conf в report_vars, убрав массив чтобы было удобнее обращаться...

  my $panes = {};
  foreach my $p (@{$runner_conf->{panes}})
  {
    my ($key) = keys %$p;
    $panes->{$key} = $p->{$key}
  }
  $runner_conf->{panes} = $panes;
  my $runner_conf_dst = $self->exchange_dir()->child('reports')->child('tmux_runner.json');
  $runner_conf_dst->touchpath;
  $runner_conf_dst->spew(encode_json($runner_conf));

  $self->$orig(@args)
};


around 'after_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  # отстреливаем процессы которые могли остаться висеть после окончания работы глючного крашера
  my $binary_name = path($self->trakt->convoy->binary('afl', $self->name))->basename;
  $self->run_command('dead_checking', "killall -9 $binary_name; true");

  return $self->$orig(@args);
};

around 'debdeps' => sub {
    my $orig = shift;
    my $self = shift;

    return ($self->$orig(@_), qw(tmux aha));
};

1;
