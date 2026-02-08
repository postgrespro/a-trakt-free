#!/usr/bin/perl

use strict;

use FindBin;
use lib $FindBin::Bin."/../lib";

use JSON;
use Path::Tiny;
use Term::Choose;

my $conf_file =  shift @ARGV;
die "Укажите конфигурационный файл первым аргументом " unless $conf_file;
#my $conf_file = "tmux-runner-conf-tmp.json";

my $json = JSON->new()->relaxed;
my $conf = $json->decode(path($conf_file)->slurp);

my $pipe = $conf->{"command-pipe"};
die "В конфиге не указан pipe-файл" unless defined $pipe;


my $menu = Term::Choose->new();

my @menu_items;

my @panes = @{$conf->{panes}};

for(my $i=0; $i<=$#panes; $i++)
{
  my $h = $panes[$i];
  my ($command_id) = keys %$h;
  my $command = $h->{$command_id};
  push @menu_items, $command->{name};
}

push @menu_items, "exit";

my $default = 0;
my $exit_count = 0;
while(1)
{
  my $cmd = $menu->choose(\@menu_items, {layout => 2, default => $default, prompt => ""});
  for(my $i=0;$i<=$#menu_items;$i++)
  {
    $default = $i if $menu_items[$i] eq $cmd;
  }

  if ($cmd eq "exit")
  {
    if (!$exit_count)
    {
      issue_command('EXIT_SOFT');
      $exit_count++;
      next;
    }
    issue_command('KILL_ALL');
    next;

  }
  issue_command("SWITCH_PANE $cmd");
}

sub issue_command
{
  my $command = shift;
  path($pipe)->append("$command\n");
}
