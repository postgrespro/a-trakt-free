package Trakt::Step::Postprocess::Hangs;

use Moose::Role;
use warnings;
use POSIX ":sys_wait_h";
use POSIX qw(setpgid);
use JSON;
use Time::HiRes;
use Path::Tiny;

has 'timeout' => (
  is => 'ro',
  lazy => 1,
  required => 1,
  isa => 'Int',
  builder => '_build_timeout',
);

sub _build_timeout
{
  my $self = shift;
  my $conf = $self->step->conf;
  return $conf->{hangs}->{timeout};
}

around 'core_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  print "Processing hangs\n";

  return unless $self->trakt->targets; # FIXME это наглый хак, чтобы оно не отрабатывало на  test.all. Надо как-то более умно сделать...

  $self->$orig(@args);

  my $target_name = $self->name;
  my $step_name = $self->step->name;

  my $res_dir = $self->res_dir->absolute;
  my $hangs_dir = $res_dir->child("hangs");
  my $json_file = $res_dir->child("stat.json");
  my $hang_res;

  path("$hangs_dir.reports")->remove_tree;

  my $hangs_confirmed_dir = path("$hangs_dir.reports")->child("confirmed");
  my $hangs_unconfirmed_dir = path("$hangs_dir.reports")->child("unconfirmed");
  my $raw_queries_folder = path("$hangs_dir.reports")->child('raw_queries');

  my $js = JSON->new->allow_nonref;

  if ($json_file->is_file)
  {
    $hang_res = $js->decode($json_file->slurp);
  }
  else
  {
    $hang_res = {};
  }

  $hang_res->{hangs} = {};
  my $step_exchange_dir = $self->step->exchange_dir;

  # set storage
  my $instance_env_hash = $self->trakt->convoy->instance_env($self->cache_dir, 'storage');
  my $instance_init_command = $self->trakt->convoy->instance_init_command($self->cache_dir, 'storage');
  if ( (defined $instance_init_command) && ($instance_init_command ne ''))
  {
    $self->run_command('hangs', $instance_init_command);
  }

  my $exchange_dir = $self->exchange_dir;
  $exchange_dir->mkpath();
  for ($hangs_dir->children)
  {
    $hangs_confirmed_dir->mkpath unless $hangs_confirmed_dir->exists;
    $hangs_unconfirmed_dir->mkpath unless $hangs_unconfirmed_dir->exists;
    $raw_queries_folder->mkpath unless $raw_queries_folder->exists;

    my $command = $self->trakt->convoy->command("afl", $target_name, $_, {verbose => 1});
    my $basename = $_->basename;
    my $t1 = Time::HiRes::time();
    my $tout = $self->timeout;
    my $is_hang = 0;

    print "$basename\n";

    my $pid = fork();
    die "не могу запустить дочерний процесс: $!" unless defined $pid;

    if ($pid == 0) # это дочерний процесс: запускаем исследуемую программу и по окончании выходим
    {
      setpgid(0, 0) or die "Не могу установить PGID: $!"; # Создаем группу под лидерством дочернего процесса чтобы можно было их всех скопом прибить
      local %ENV = %ENV;
      %ENV = (%ENV, %{$instance_env_hash});
      $ENV{ASAN_OPTIONS} = "abort_on_error=1:detect_leaks=0";
      system("stdbuf -o0 $command 2>&1 > $hangs_confirmed_dir/$basename"); # stdbuf -o0 выключает буферизацию stdout чтобы весь вывод попадал в файл
      exit;
    }

    # это родительский процесс. Ждем завершения дочернего процесса, если не дождались считаем зависанием...
    while (1) {
      my $elapsed = Time::HiRes::time() - $t1;

      if ($elapsed > $tout) {
        $is_hang = 1;
        kill(9, -$pid); # минус тут означает что убиваем всю группу процессов возглавляемых $pid. Убьем child'а со всеми его потомками
        last;
      }

      Time::HiRes::sleep(0.1);

      my $res = waitpid($pid, WNOHANG);
      die sprintf("Что то пошло не так, спустя %.2f s, ошибка: $!", $elapsed) if ($res == -1);

      last if $res;
    }

    my $t2 = Time::HiRes::time();
    my $tm = $t2 - $t1;
    printf("elapsed - %.2f s\n", $tm);
    print "catched - HANG!\n" if $is_hang;
    print "\n";

    $hang_res->{hangs}->{$basename} = {time => $tm, is_real_hang => $is_hang};
    $hangs_confirmed_dir->child($basename)->move($hangs_unconfirmed_dir->child($basename)) if ! $is_hang;

    if ( my $command = $self->trakt->convoy->dump_reproducer_command( $target_name, $_, $raw_queries_folder->child( $_->basename ) ) ) {
      print "Dump reproducer: $command\n";
      local %ENV = %ENV;
      %ENV = (%ENV, %{$instance_env_hash});
      system( $command );
    }
  }
  $json_file->spew($js->pretty->encode($hang_res));

};

1;
