#!/usr/bin/perl

use strict;

use FindBin;
use lib $FindBin::Bin."/../lib";

use JSON;
use Path::Tiny;
use TmuxPaner::RootPane;
use POSIX;
use String::ShellQuote;

my $bin_dir = $FindBin::Bin;

my $conf_file =  shift @ARGV;
die "Укажите конфигурационный файл первым аргументом " unless $conf_file;

#print $conf_file;
#my $conf_file = "tmux-runner-conf-tmp.json";

my $conf_file_sq = shell_quote($conf_file);

my $json = JSON->new()->relaxed;
my $conf = $json->decode(path($conf_file)->slurp);
my $panes = {};

my $pipe = $conf->{"command-pipe"};
my $commands_log = $conf->{"commands-log"};

die "В конфиге не указан pipe-файл" unless defined $pipe;


unlink $pipe || die "Cant clean pipe $pipe before use"  if -e $pipe;
POSIX::mkfifo($pipe, 0700) || die "can't mkfifo $pipe: $!";



my $paner = TmuxPaner::RootPane->new(direction => 'horizontal', parent_size => 15, log_dir => ".", log => $conf->{'paner-log'});

foreach my $h (@{$conf->{panes}})
{
  my ($pane_id) = keys %$h;
  my $pane_dsk = $h->{$pane_id};
  $paner->add_pane($pane_dsk);
  $panes->{$pane_id} = $pane_dsk;
}

my $menu_pane = TmuxPaner::RootPane->new(direction => 'vertical', parent_size=>5);

$menu_pane->add_pane('menu',"$bin_dir/tmux_runner_menu.pl $conf_file_sq");
$menu_pane->focus();


sub issue_command
{
  my $command = shift;
  path($pipe)->append("$command\n");
}

while (1)
{
  # next line blocks till there's a reader
  open (my $fh, "<", $pipe) || die "can't open $pipe: $!";
  while (my $line = <$fh>)
  {
    process_pipe_command($line);
  }
}


sub process_pipe_command
{
    my $line = shift;
    path($commands_log)->append($line) if $commands_log;
    my @args = split " ", $line;
    my $command = shift @args;

    if ($command eq 'SWITCH_PANE')
    {
      my $pane_id = shift @args;
      $paner->show_pane($pane_id);
    }
    elsif($command eq 'CAPTURE')
    {
      my $pane_id = shift @args;
      my $mode = shift(@args) || "txt";
      my $dst = shift(@args);

      die "Do not know where to capture" unless defined $dst || $panes->{$pane_id}->{capture};

      $dst ||= $panes->{$pane_id}->{capture}.".$mode";
      $paner->capture_pane($pane_id, $dst, $mode eq 'ascii');
    }
    elsif ($command eq 'KILL_ALL')
    {
        unlink $pipe || die "Cant clean pipe $pipe after use";
        $paner->kill_all_panes();
    }
    elsif ($command eq 'SET_TRIGGER')
    {
        my $type = shift @args;
        my $target = shift @args;
        my $trigger = join " ", @args;
        die "Unknown event type '$type'" unless $type eq 'pane-exited';
        my $command = "echo $trigger > $pipe";
        $paner->set_on_exit($target, $command);
    } else
    {
      if ($conf->{triggers}->{$command})
      {
        my $shell_command = $conf->{triggers}->{$command}->{command};
        my $pipe_commands = $conf->{triggers}->{$command}->{pipe_commands};
        if ($shell_command)
        {
          `$shell_command`;
        } elsif ($pipe_commands)
        {
          foreach my $p_cmd (@$pipe_commands)
          {
            process_pipe_command($p_cmd);
          }
        } else
        {
           die "WTF?!";
        }
      }
    }
}



`sleep 1000`;

#die;

#$paner->add_pane('ping','ping 8.8.8.8', "do_log");
#$paner->add_pane('top','top');
#$paner->add_pane('date','watch date');


