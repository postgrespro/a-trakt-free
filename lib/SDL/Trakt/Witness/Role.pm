package SDL::Trakt::Witness::Role;

use Moose::Role;

has '_witness_commands_stash' => (
  is => 'ro',
  required => 1,
  isa => 'HashRef[Str]',
  default => sub { {} },
);
has 'witness_tag_prefix' => (is => 'rw', isa => "Str", default => "");


requires 'cache_dir';
requires 'exchange_dir';

sub log_before_command
{
  my $self = shift;
  my $tag = shift;
  my $command = shift;
  my $real_command = shift;
  my $comment = shift;

  $self->cache_dir->mkpath;
  my $log_name = $self->cache_dir->child("commands.log");

  $log_name->append("====================================\n");
  $log_name->append("Executing: '$real_command'\n");
  $log_name->append("====================================\n");
}

sub log_after_command
{
  my $self = shift;
  my $tag = shift;
  my $command = shift;
  my $real_command = shift;
  my $output = shift;
  my $comment = shift;

  if ($output)
  {
    my $log_name = $self->cache_dir->child("commands.log");
    $log_name->append($output);
  }

  $tag = $self->witness_tag_prefix . $tag;

  my $stash = $self->_witness_commands_stash;
  $stash->{$tag} = "" unless defined $stash->{$tag};
  $stash->{$tag} .= $command . "\n";

  # FIXME это пипец неэффективно каждый раз перезаписывать файл целиком
  # но объемы у нас тут маленькие высокой нагрузки мы не создадим
  # поэтому пока будет так
  my $report_dir = $self->exchange_dir->child("reports");
  $report_dir->mkpath();
  $report_dir->child('commands.json')->spew(JSON->new->pretty->encode($stash));
}

1;
