package TmuxPaner::RootPane;

use Moo;
use Carp;

use Path::Tiny;

has '_panes' => (
    is => 'rw',
    default => undef,
);

has '_current' => (
    is => 'rw',
    default => undef,
);

has 'direction' => (
    is => 'ro',
    default => 'vertical',
    isa => sub { die "$_[0] is not 'vertical' or 'horizontal'" if $_[0] ne 'vertical' and $_[0] ne 'horizontal'}

);

has '_placeholder_pane' => (
    is => 'rw',
    default => undef,
);


has 'parent_size' => (
    is => 'rw',
    default => undef,
);

has 'size' => (
    is => 'rw',
    default => undef,
);

has 'log_dir' => (
    is => 'rw',
    default => undef,
);

has 'log' => (
    is => 'rw',
    default => undef,
);

=head
sub set_on_exit_all
{
  # для обратной совместимости... Позже подумать об удалении или перемещении
  my $self = shift;
  my $name = shift;
  my $command = shift;

  my $pane_id = $self->_panes->{$name};

  die "Pane $name not found" unless defined $pane_id;

  my $res = `tmux set-hook pane-exited 'run-shell -b "$command"' `;
}
=cut

my $hook_count = 0;

sub set_on_exit
{
  my $self = shift;
  my $name = shift;
  my $command = shift;

  my $pane_id = $self->_panes->{$name};

  die "Pane $name not found" unless defined $pane_id;
  $hook_count++;
  # пока что используем глобльные хуки. Локальные по какой-то причине не работают даже там где они есть: https://github.com/tmux/tmux/issues/3736
  my $res = $self->_run_tmux_command('set-hook', "-g pane-exited[$hook_count] 'run-shell -b \"$command\"'");
}

sub BUILD
{
  my $self = shift;

  $self->log(path($self->log)) if $self->log;
  $self->log->spew("Starting new TmuxPaner session\n") if $self->log;

  my @tmux_args = ("split-window");

  push @tmux_args, "-d"; # do not focus on new pane
  push @tmux_args, "-P"; # print pane_id as a result;
  push @tmux_args, "-F '#{pane_id}'";

  push @tmux_args, "-v" if $self->direction eq 'vertical';
  push @tmux_args, "-h" if $self->direction eq 'horizontal';
  push @tmux_args, "-l ".$self->size if $self->size;


  push @tmux_args, "'echo This is a PLACEHOLDER pane; while true ; do sleep 1 ; done'"; # infinite command for placeholder

  my $pane_id = $self->_run_tmux_command(@tmux_args);
  chomp $pane_id;

  $self->_placeholder_pane($pane_id);

  if ($self->parent_size)
  {
    my @tmux_args = ("resize-pane");
    push @tmux_args, "-y ".$self->parent_size  if $self->direction eq 'vertical';
    push @tmux_args, "-x ".$self->parent_size if $self->direction eq 'horizontal';
    $self->_run_tmux_command(@tmux_args);
  }
}

sub add_pane
{
    my $self = shift;

    my $name;
    my $command;
    my $do_log;
    my $log_file;
    if ( ref $_[0] eq 'HASH')
    {
        my $params = shift;
        $name = $params->{name};
        $command = $params->{command};
        $log_file = $params->{log};
    } else
    {
        #FIXME старое повеение, позже -- зачистить...
        $name = shift;
        $command = shift;
        $do_log = shift;
        if ($do_log && $self->log_dir)
        {
          my $log_dir = $self->log_dir;
          $log_file = "$log_dir/$name.log";
        }
    }
    my $command_src = $command;
    #escaping slashes and quotes

    $command =~ s/\\/\\\\/g;
    $command =~ s/\"/\\\"/g;

    $command = "bash -c \"$command\"";

    if (defined $log_file)
    {
      `echo 'Command to run: $command_src' > $log_file`;

      $command = "unbuffer $command 2>&1 | tee -a $log_file";

      `echo 'Actual command: $command' >> $log_file`;
    }

    my $pane_id = $self->_run_tmux_command('new-window', "-P -d -n $name -F '#{pane_id}' '$command' ");
    chomp $pane_id;

    if ($self->_placeholder_pane)
    {
      my $placeholder_id = $self->_placeholder_pane;
      $self->_run_tmux_command('swap-pane', "-d -s $placeholder_id -t $pane_id");
      $self->_run_tmux_command('kill-pane', "-t $placeholder_id");
      $self->_placeholder_pane(undef);
      $self->_panes({});
      $self->_current($name);
    }
    $self->_panes->{$name} = $pane_id;
}

sub show_pane
{
    my $self = shift;

    my $name = shift;
    return if $name eq $self->_current;

    die "Unknown pane '$name'" unless defined $self->_panes->{$name};

    my $current_id = $self->_panes->{$self->_current};
    my $target_id = $self->_panes->{$name};
    my $current_name = $self->_current;

    $self->_run_tmux_command('swap-pane', "-d -s $current_id -t $target_id");
    $self->_run_tmux_command('rename-window', "-t $current_id $current_name");

    $self->_current($name);
}

sub focus
{
    my $self = shift;
    my $name = shift;

    my $current_id = $self->_panes->{$self->_current};

    $self->_run_tmux_command('select-pane', "-t $current_id");
}

sub capture_pane
{
  my $self = shift;
  my $name = shift;
  my $file_name = shift;
  my $use_ascii = shift; # colorful picture

  my $more_options = "";
  $more_options .= " -e" if $use_ascii;

  my $pane_id = $self->_panes->{$name};
  die unless $pane_id;

  $self->_run_tmux_command('capture-pane', "-t $pane_id $more_options -p >$file_name");

}

# in case we aknolaged that pane was closed we should forget about it
sub forget_pane
{
  my $self = shift;
  my $name = shift;

  delete $self->_panes->{$name};
}

sub kill_pane
{
  my $self = shift;
  my $name = shift;
  my $pane_id = $self->_panes->{$name};

  $self->_run_tmux_command('kill-session', "-t $pane_id");
  delete $self->_panes->{$name};
}

# FIXME this should be rewritten or removed
sub kill_all_panes
{
  my $self = shift;
  $self->_run_tmux_command(qw(kill-session));
}

sub _run_tmux_command
{
  my $self = shift;
  my @args = @_;
  my $command = "tmux ". join(" ",@args);

  $self->log->append("Running command: `$command`\n") if $self->log;
  my $res = `$command`;
  $self->log->append("Return code: $?\n") if $self->log;
  $self->log->append("OUTPUT: '$res'\n") if $self->log;

  if ($?)
  {
    print STDERR "Error running command `$command`";
    print STDERR "Return Code = $?";
    confess();
  }
  return $res;
}

1;
