package Trakt::Role::CoverageLcov;

use Moose::Role;
use utf8;

use Path::Tiny;
use String::ShellQuote;

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


1;
