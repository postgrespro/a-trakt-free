package Trakt::Step::FuzzCoverage;

use Moose;
# Base class for building coverage step.

extends 'Trakt::Step';
with "Trakt::Step::FuzzCoverage::SelfReport";


# ########################################

package Trakt::Step::FuzzCoverage::Target;

use Moose;
extends 'Trakt::Target';

with "Trakt::Step::FuzzCoverage::SelfReportTarget", "Trakt::Role::CoverageLcov";

use Path::Tiny;
use String::ShellQuote;


sub get_process_sample_command
{
  my $self = shift;
  my $target_name = shift;
  my $sample_file = shift;

  my $env_h = $self->instance_env('coverage');
  my $env_s = "";
  foreach my $key (keys %$env_h)
  {
    $env_s.="$key=".shell_quote($env_h->{$key}). " ";     #FIXME перевести это в instance_env_str из конвоя
  }
  return "$env_s". $self->trakt->convoy->command('coverage', $target_name, $sample_file);
}

sub get_prepare_context_command
{
  my $self = shift;
  my $res = $self->trakt->convoy->instance_init_command($self->cache_dir->child('instances_contexts'), 'coverage');
  return $res || "true";  # Суммарная команда у нас собирается через && и какая-то комнада там между эндами нужна. Поэтому если команды нет, то возвращаем true
}

around 'before_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  my $cache_dir = $self->cache_dir;

  $self->$orig(@args);

  $self->cache_dir->mkpath();
};

around 'core_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  my $target_name = $self->name;
  my $res_dir = $self->res_dir;
  my $samples_dir = $res_dir->child('samples')->absolute;

  my $cache_dir = $self->cache_dir;

  my $profile_dir = $cache_dir->child("raw_profile");
  $self->run_command("prepare", "mkdir -p $profile_dir");

  my $command = $self->get_process_sample_command($self->name, '$file');
  my $prepare_context_command = $self->get_prepare_context_command();

  $self->run_command('process_samples',"for file in $samples_dir/* ; do echo Processing \$file... && $prepare_context_command && $command ; done ; true"); # true чтобы $? всегда был по окончанию 0 и мы не прерывались по неуспешности запуска

  $self->process_coverage($target_name, $self->trakt->convoy->affected_binaries('coverage', $target_name));

  $profile_dir->remove_tree;
  $self->$orig(@args);
};

1;
