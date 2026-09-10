package Trakt::Step::FuzzSydrFuzz;

# Временная копия чтобы раньше времени не ломать фаззинг сетевого пакетра от Trakt::Common::FuzzAfl зависящего

use Moose;
extends 'Trakt::Step';

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

package Trakt::Step::FuzzSydrFuzz::Target;

use Moose;
extends 'Trakt::Target';

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

around 'core_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  my $step_name = $self->step->name;
  my $target_name = $self->name;

  my $exch_dir = $self->exchange_dir;
  my $cache_dir = $self->cache_dir->absolute;
  my $res_dir = $self->trakt->res_dir->child($target_name);


  my $afl_bin_dir = $self->trakt->step('build')->target('afl')->cache_dir->child('build_dir/install/AFLplusplus/bin/')->absolute;    # FIXME надо AFL ставить не в cache dir, а в exchange_dir

  my $in_dir = $self->sklad->samples->get->absolute;

  my $nproc = $self->trakt->intendant->nproc;
  die "Слишком мало процессоров ($nproc)!" if $nproc < 2;

  my $sydr_jobs = int($nproc / 5);
  $sydr_jobs = 1 if $sydr_jobs <= 0;

  my $afl_slave_jobs = $nproc - $sydr_jobs -1;

  my $afl_target_command = $self->trakt->convoy->command('afl',$self->name,'@@');
  my $plain_target_command = $self->trakt->convoy->command('plain',$self->name,'@@');


  my $sydrfuzz_conf = << "END_CONF";
#exit-on-time = 7200
#exit-on-time = 120

[sydr]
args = "-s 90 -j 1"
target = "$plain_target_command"
jobs = $sydr_jobs

[[aflplusplus]]
target = "$afl_target_command"
args = "-t 60000 -i $in_dir"
path = "$afl_bin_dir"
jobs = 1

[[aflplusplus]]
target = "$afl_target_command"
args = "-t 60000"
#path = "$afl_bin_dir"
jobs = $afl_slave_jobs

END_CONF

  my $sydrfuzz_conf_file = $cache_dir->child('sydr-fuzz.toml');
  $sydrfuzz_conf_file->spew($sydrfuzz_conf);

  $self->report_file($sydrfuzz_conf_file);

  my $sydr_dir = path($self->trakt->conf->{sydr});
  $sydr_dir = $sydr_dir->absolute($self->trakt->top_dir) if $sydr_dir->is_relative;
  die "Sydr dir '$sydr_dir' is not found" unless $sydr_dir->is_dir();

  my $fuzzer_command = "cd $cache_dir ; $sydr_dir/sydr-fuzz -c $cache_dir/sydr-fuzz.toml run";


  my $pipe_file = $self->cache_dir->child("tmux_runner.pipe");
  my $runner_commands_log = $self->cache_dir->child("tmux_runner.commands.log");
  my $paner_log = $self->cache_dir->child("tmux_runner.paner.log");


  my $afl_env = $self->afl_env();
  my $afl_extra_options = $self->afl_extra_options();

  die "Директория с сэмплами '$in_dir' не существует" unless -d $in_dir;

  if (-e "$res_dir/sydrfuzz_ui.ascii")
  {
    print "Цель $target_name уже была успешно запущена, пропускаю\n";
    return 1;
  }

  my $watchdog_command = $self->find_bin('afl_watch_dog.pl')." ".
                                          shell_quote($self->afl_limits_config)." ".
                                          shell_quote($self->cache_dir->child('sydr-fuzz-out/aflplusplus//afl_main-worker/fuzzer_stats')). " ". shell_quote($pipe_file);
my $runner_conf = {
  panes => [
    {top      => { name => 'top',      command => 'top'          }},
    {date     => { name => 'date',     command => 'watch date'   }},
    {fuzzer   => { name => 'fuzzer',   command => $fuzzer_command,   capture => "$cache_dir/sydrfuzz_ui",  log => "$cache_dir/sydrfuzz.log" }},
    {watchdog => { name => "watchdog-$target_name", command => "watch $watchdog_command"}},
  ],
  triggers =>
    { STOP_FUZZER => { command       => 'pkill -15 sydr-fuzz; pkill -15 afl-fuzz'}, # Недостаточно изящно, но дело свое делает
      FINISH       => { pipe_commands => ["CAPTURE fuzzer", "CAPTURE fuzzer ascii", "EXIT_SOFT"]},
      EXIT_SOFT    => { pipe_commands => ["SET_TRIGGER pane-exited fuzzer KILL_ALL","STOP_FUZZER"]},
    },
  "command-pipe" => "$pipe_file",
  "commands-log" => "$runner_commands_log",
  "paner-log" => "$paner_log",
};

  my $runner_bin = $self->find_bin('tmux_runner.pl');
  my $runner_bin_sq = shell_quote($runner_bin);
  path($self->cache_dir())->mkpath;
  my $runner_conf_file = path($self->cache_dir())->child("tmux_runner.conf");
  $runner_conf_file->spew(JSON->new->pretty->encode($runner_conf));
  my $runner_conf_file_sq = shell_quote($runner_conf_file);


  my $tmux_command = "tmux new-session \"bash -c '$runner_bin_sq $runner_conf_file_sq' 2>&1 >$cache_dir/tmux_runner.log \" 2>&1 >$cache_dir/tmux.log";

  $self->run_command('run_fuzzing', "$tmux_command");


  unless( -e "$cache_dir/sydrfuzz_ui.ascii")
  {
    print "Судя по всему либо вышли вручную, либо упали в процессе работы. В обоих случаях дальнешую работу прекращаем";
    $self->after_run(); # убираем за собой в любом случае
    die;
  }

  # Корпус с которого фаззинг стартовался переиминовываем в corpus.original
  $self->run_command('prepare_res', "mv $cache_dir/sydr-fuzz-out/corpus $cache_dir/sydr-fuzz-out/corpus.original");
  $self->run_command('prepare_res', "mkdir $cache_dir/sydr-fuzz-out/corpus");
  # Запускаем cmin над результатами фаззинга
  $self->run_command('prepare_res', "cd $cache_dir ; $sydr_dir/sydr-fuzz -c $cache_dir/sydr-fuzz.toml cmin");

  # Запускаем security и casr над результатами фаззинга
  $self->run_command('prepare_res', "cd $cache_dir ; $sydr_dir/sydr-fuzz -c $cache_dir/sydr-fuzz.toml security --jobs $nproc" );
  $self->run_command('prepare_res', "cd $cache_dir ; $sydr_dir/sydr-fuzz -c $cache_dir/sydr-fuzz.toml casr --jobs $nproc" );

  $res_dir->mkpath();
  $self->run_command('prepare_res', "cp $cache_dir/sydrfuzz_ui.ascii $cache_dir/sydrfuzz_ui.txt $res_dir");
  $self->run_command('prepare_res', "cat $res_dir/sydrfuzz_ui.ascii | aha > $res_dir/sydrfuzz_ui.html");

  $self->run_command('prepare_res', "mkdir -p $res_dir/samples");
  $self->run_command('prepare_res', "cp $cache_dir/sydr-fuzz-out/corpus/* $res_dir/samples");


  $self->run_command('prepare_res', "mkdir -p $res_dir/security-crashes");
  $self->run_command('prepare_res', "cp $cache_dir/sydr-fuzz-out/crashes/* $res_dir/security-crashes || true"); # do not fail if there are no files, it is ok to have none

  $self->run_command('prepare_res', "cp -r $cache_dir/sydr-fuzz-out/aflplusplus/afl_main-worker/crashes $res_dir");
  $self->run_command('prepare_res', "cp -r $cache_dir/sydr-fuzz-out/aflplusplus/afl_main-worker/hangs/ $res_dir");

  $self->run_command('prepare_res', "cp -r $cache_dir/sydr-fuzz-out/security/ $res_dir");
  $self->run_command('prepare_res', "cp -r $cache_dir/sydr-fuzz-out/security-unique/ $res_dir");
  $self->run_command('prepare_res', "cp -r $cache_dir/sydr-fuzz-out//security-verified/ $res_dir");

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

    return ($self->$orig(@_), qw(tmux aha python3-scipy));
};



1;
