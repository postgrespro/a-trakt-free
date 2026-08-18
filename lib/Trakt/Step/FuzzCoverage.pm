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


sub get_process_sample_env
{
  my $self = shift;

  my $profile_dir = path($self->cache_dir."/raw_profile")->absolute;
  my $h = $self->trakt->convoy->instance_env($self->cache_dir, 'storage');
  $h->{LLVM_PROFILE_FILE} = "$profile_dir/%p_%m.profraw";
  return $h;
}

sub get_process_sample_command
{
  my $self = shift;
  my $target_name = shift;
  my $sample_file = shift;

  my $env_h = $self->get_process_sample_env();

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

  # FIXME этот метод используется в fuzzing.libpq который у нас legacy. Должно все уехать в convoy и через сюда не оверрайдится.

  my $res = $self->trakt->convoy->instance_init_command($self->cache_dir, 'storage');
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

  my $trakt = $self->trakt;
  my $target_name = $self->name;
  my $res_dir =$trakt->res_dir->child($target_name);
  my $samples_dir = $res_dir->child('samples')->absolute;

  my $cache_dir = $self->cache_dir;
  my $exch_dir = $self->exchange_dir;
  my $profile_dir = $cache_dir->child("raw_profile");

  $self->run_command("prepare", "mkdir -p $profile_dir");

  my $binaries = join (" ", map {shell_quote($_)} @{$trakt->convoy->affected_binaries('coverage', $target_name)});

  my $command = $self->get_process_sample_command($self->name, '$file');
  my $prepare_context_command = $self->get_prepare_context_command();

  $self->run_command('process_samples',"for file in $samples_dir/* ; do echo Processing \$file... && $prepare_context_command && $command ; done ; true"); # true чтобы $? всегда был по окончанию 0 и мы не прерывались по неуспешности запуска

  my $llvm = $trakt->intendant->llvm;
  my $lcov_file = $exch_dir->child('profdata.lcov');

# А это появится только в 13м clang'е
#  my $compilation_dir = $self->trakt->step('build')->target('coverage')->cache_dir->child('build_dir/repos/postgrespro');

  $self->run_command('generate_coverage', $llvm->binary('llvm-profdata')." merge -output=$cache_dir/profdata $profile_dir/*.profraw");
  $self->run_command('generate_coverage', $llvm->binary('llvm-cov'). " export ${binaries} -instr-profile=${cache_dir}/profdata -format=lcov > $lcov_file");
#  $self->run_command('generate_coverage',"$llvm->binary('llvm-cov'). " export ${binaries} -instr-profile=${cache_dir}/profdata -format=lcov -compilation-dir=$compilation_dir > $lcov_file);
  $self->exec_bin('generate_coverage', 'fix-lcov.pl', "$lcov_file");
  $self->run_command('generate_coverage',"genhtml -o ${cache_dir}/$target_name.html $lcov_file");
  $self->run_command('generate_coverage',"cd ${cache_dir}; tar -cvzf $target_name.coverage.html.tgz $target_name.html");


  $self->run_command('saving_results',"cp ${cache_dir}/$target_name.coverage.html.tgz $res_dir/$target_name.coverage.html.tgz");

  $profile_dir->remove_tree;
  $self->$orig(@args);
};

#around 'after_run' => sub {
#  my $orig = shift;
#  my $self = shift;
#  my @args = @_;
#
#  return $self->$orig(@args);
#}




1;
