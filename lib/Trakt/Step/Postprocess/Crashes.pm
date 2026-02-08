package Trakt::Step::Postprocess::Crashes;

use Moose::Role;
use warnings;
use JSON;
use Digest::MD5 qw(md5_hex);

around 'core_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  return unless $self->trakt->targets; # FIXME это наглый хак, чтобы оно не отрабатывало на  test.all. Надо как-то более умно сделать...

  $self->$orig(@args);

  my $target_name = $self->name;

  my $res_dir = $self->res_dir->absolute;
  my $json_file = $res_dir->child("stat.json");
  my $crashes_res;

  my $js = JSON->new->allow_nonref;

  if ($json_file->is_file)
  {
    $crashes_res = $js->decode($json_file->slurp);
  }
  else
  {
    $crashes_res = {};
  }
  $crashes_res->{crashes} = {};

  my $instance_env_hash = $self->trakt->convoy->instance_env($self->cache_dir, 'storage');
  my $instance_env_str =  $self->trakt->convoy->instance_env_str($self->cache_dir, 'storage');

  my $instance_init_command = $self->trakt->convoy->instance_init_command($self->cache_dir, 'storage');
  if ( (defined $instance_init_command) && ($instance_init_command ne ''))
  {
    $self->run_command('crashes', $instance_init_command);
  }

  my $raw_queries_folder = $res_dir->child('crashes.reports')->child('raw_queries');
  $raw_queries_folder->mkpath unless $raw_queries_folder->exists;

  print "Processing crashes\n";
  my $num = 0;
  my %trap_dir_names;
  foreach my $crash_file ($res_dir->child('crashes')->children)
  {
    next if $crash_file->basename eq 'README.txt'; #AFL++ have it in crashes dir, we should ignore it
    next if $crash_file->basename eq '.work'; #Crusher have it in crashes dir, we should ignore it
    my $command = $self->trakt->convoy->command('afl',$self->name, $crash_file,{verbose => 1}) . " 2>&1";
    print "Processing crash : $command\n";
    my $res;
    {
      local %ENV = %ENV;

      %ENV = (%ENV, %{$instance_env_hash});
      #      $ENV{ASAN_OPTIONS} = "abort_on_error=1";
            $ENV{ASAN_OPTIONS} = "abort_on_error=1:detect_leaks=0";

      $res = `$command`;
    }
    my $exit_value = $? >> 8;
    my $signal_num = $? & 127;
    my $dumped_core = $? & 128;
    my $confirmed;
    my $res_group; # Группа, к которой относится крэш
    my $res_dir_name; # Директория, в которой сохраняется результат крэша
    # Обычно совпадает с $res_group, но есть исключения.
    # Для групп Assert(...) свои правила формирования имен директорий.
    # директория называется assert_cacheId...
    # Т.е. берем латинские буквы начиная от скобок и до первой не-латинской буквы
    # добавляем многоточие
    # Если есть коллизия, т.е. два разных ассерта начинаются с cacheId то ко второму добавляет цифру 2 и т.д.
    # Перед многоточием
    # Для нумерации упорядочиваем их по алфавиту, чтобы они воспроизводимо нумеровались
    if ($signal_num)
    {
      $confirmed = 1;
      $res_dir_name = $res_group = "other";
      if ($res =~ m{ERROR: AddressSanitizer: (\S+)}s)
      {
        $res_dir_name = $res_group = $1;
      }
      if ( ($res =~ m{TRAP: FailedAssertion\("(.+?)"}s) || ($res =~ m{ЛОВУШКА: нарушение Assert\("(.+?)"}s) )
      {
        my $assertion = $1;
        $res_group = "Assert($assertion)";
        $res_dir_name = "Assert_".md5_hex($assertion);
        unless ($trap_dir_names{$assertion})
        {
          $trap_dir_names{$assertion} = $res_dir_name;
        }
      }

      if ( my $command = $self->trakt->convoy->dump_reproducer_command( $self->name, $crash_file, $raw_queries_folder->child( $crash_file->basename ) ) )
      {
        print "Dump reproducer: $command\n";
        local %ENV = %ENV;
        %ENV = (%ENV, %{$instance_env_hash});
        system( $command );
      }
    }
    else
    {
      $confirmed = 0;
      $res_dir_name = $res_group = "unconfirmed";
    }
    my $report_name = $res_dir->child('crashes.reports')->child($res_dir_name);
    $report_name->mkpath;
    $report_name = $report_name->child($crash_file->basename.".txt");
    $report_name->spew("Command: $instance_env_str $command\n");
    $report_name->append("============================\n");
    $report_name->append("$res");

    $crashes_res->{crashes}->{$crash_file->basename} = {crash_type => $res_group, confirmed => $confirmed, exit_value => $exit_value, signal_num => $signal_num, dumped_core => $dumped_core};
  }

  my @trap_bad_names = sort keys %trap_dir_names;
  foreach my $assertion (@trap_bad_names)
  {
    my $str_num = $num +=1;
    if ($num == 1)
    {
      $str_num = '';
    }
    $assertion =~ m{(\w+)};
    my $good_name = 'assert_'.$1.$str_num.'...';
    my $good_tree = $res_dir->child('crashes.reports')->child($good_name);
    if ($good_tree->exists)
    {
      $good_tree->remove_tree( { safe => 0 } );
    }
    $res_dir->child('crashes.reports')->child($trap_dir_names{$assertion})->move($good_tree);
  }

  $json_file->spew($js->pretty->encode($crashes_res));
};


1;
