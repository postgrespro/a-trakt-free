package Trakt::Step::FuzzCoverage::Total;

use strict;

use Moose::Role;
use Path::Tiny;

use Code::CovTool;
use Code::CovTool::Sources;


around 'after_run' => sub
{
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  my $trakt = $self->trakt;
  my @targets = $trakt->targets; # берем "естественные" цели тракта
  my $cache_dir = $self->cache_dir;
  my $res_dir =$trakt->res_dir;

  my $cov_step = $trakt->step('coverage');
  my $build_target = $trakt->step('build')->target('coverage');

  my $src_dir = $build_target->stapel->src_dir->absolute;

  # Объект с исходными файлами
  my $src_o = Code::CovTool::Sources->new( src_dir => $src_dir );

    # Объекты покрытия которые планируем суммировать
    #    my $f1  = Code::CovTool->new( src => $src, file => 'data.lcov' );

  # Для суммирования необходимо создать пустой объект и добавить в него объекты покрытия
  my $total = Code::CovTool->new( src => $src_o );

  foreach my $target_name (@targets)
  {
    my $target = $cov_step->target($target_name);
    my $lcov_file = $target->exchange_dir->child('profdata.lcov');

    print "============== ".$lcov_file."\n";

    my $detached_lcov_file = Path::Tiny->tempfile;
    $self->lcov_detach_path($lcov_file, $src_dir, $detached_lcov_file);

    my $cov  = Code::CovTool->new( src => $src_o, file => "$detached_lcov_file" );
    $total->append( $cov );
  }
  my $total_lcov_file = $self->exchange_dir->child('coverage_total');
  $total_lcov_file->spew($total->export);
  my $total_cov_base_name = 'coverage_total.html';
  my $total_cov_html = $cache_dir->child($total_cov_base_name);


  $self->run_command('generate_coverage',"genhtml -o $total_cov_html $total_lcov_file");
  $self->run_command('generate_coverage',"tar -C $cache_dir -cvzf $total_cov_html.tgz $total_cov_base_name");

  $self->run_command('saving_results',"cp $total_cov_html.tgz $res_dir");

  $self->$orig(@args);
};


# Грязный хак: у нас метод detach отделящий часть дерева от покрытия не рефлизован пока,
# поэтому мы делем импровизированный своими силами.
sub lcov_detach_path
{
  my $self = shift;
  my $lcov_file = shift;
  my $detach_dir = shift;
  my $res_file = shift;

  my $src_o = Code::CovTool::Sources->new( src_dir => '/' ); # Чтобы точно попало всё.
  my $lcov = Code::CovTool->new( src => $src_o, file => "$lcov_file" );

  my $detached_src_lcov = $lcov->clip("$detach_dir");

  path($res_file)->spew($detached_src_lcov->export);
}


1;


