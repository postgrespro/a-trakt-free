package Trakt::Step::FuzzCoverage;

use Moose;
# Base class for building coverage step.

extends 'Trakt::Step';
with "Trakt::Step::FuzzCoverage::SelfReport";


# ########################################

package Trakt::Step::FuzzCoverage::Target;

use Moose;
extends 'Trakt::Target';

with "Trakt::Step::FuzzCoverage::SelfReportTarget";

use Path::Tiny;
use String::ShellQuote;


# FIXME этот метод общий для всех шагов так или иначе работающих с clang-поркрытием. Надо вынести его в общую для них роль
around 'instance_env' => sub
{
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  my $res = $self->$orig(@args);

  my $profile_dir = path($self->cache_dir)->child("raw_profile")->absolute;
  $res->{LLVM_PROFILE_FILE} = "$profile_dir/%p_%m.profraw";

  return $res;
};

# FIXME этот метод общий для всех шагов так или иначе работающих с clang-поркрытием. Надо вынести его в общую для них роль
sub process_coverage
{
  my $self = shift;
  my $cov_codename = shift;
  my $binaries = shift;

  my $binaries_str = join (" ", map {shell_quote($_)} @$binaries);

  my $cache_dir = $self->cache_dir;
  my $exch_dir = $self->exchange_dir;

  my $llvm = $self->trakt->intendant->llvm;
  my $lcov_file = $exch_dir->child($cov_codename.'.profdata.lcov');
  my $profile_dir = $cache_dir->child("raw_profile");
  my $profdata_file = $cache_dir->child($cov_codename.".profdata");       # Файл со смердженными данными профайла

# А это появится только в 13м clang'е
#  my $compilation_dir = $self->trakt->step('build')->target('coverage')->cache_dir->child('build_dir/repos/postgrespro');

  $self->run_command('generate_coverage', $llvm->binary('llvm-profdata')." merge -output=$profdata_file $profile_dir/*.profraw");
  $self->run_command('generate_coverage', $llvm->binary('llvm-cov'). " export $binaries_str -instr-profile=$profdata_file -format=lcov > $lcov_file");
#  $self->run_command('generate_coverage',"$llvm->binary('llvm-cov'). " export $binaries_str -instr-profile=${cache_dir}/profdata -format=lcov -compilation-dir=$compilation_dir > $lcov_file);
  $self->exec_bin('generate_coverage', 'fix-lcov.pl', "$lcov_file");

  $self->genhtml($lcov_file, "$cov_codename.coverage.html");
}

# FIXME этот метод общий для всех шагов так или иначе работающих с clang-поркрытием. Надо вынести его в общую для них роль
sub genhtml
{
  my $self = shift;
  my $lcov_file = shift;
  my $res_file_base = shift;

  my $cache_dir = $self->cache_dir;
  my $res_dir = $self->res_dir;

  $self->run_command('generate_coverage',"genhtml -o ${cache_dir}/$res_file_base $lcov_file");
  $self->run_command('generate_coverage',"cd ${cache_dir}; tar -cvzf $res_file_base.tgz $res_file_base");
  $self->run_command('saving_results',"cp ${cache_dir}/$res_file_base.tgz $res_dir/$res_file_base.tgz");
}

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
