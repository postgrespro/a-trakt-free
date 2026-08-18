use strict;
use FindBin;
use Path::Tiny;
# Основные
use lib $FindBin::Bin."/../lib";
# Хелпер
use lib $FindBin::Bin."/lib";

use Scalar::Util qw( refaddr );
use Test::Exception;
use Test::More;

use Code::CovTool;
use Code::CovTool::Sources;

use Local::Test::Helper;

my $samples_dir = Local::Test::Helper::prepare_samples_dir(
  path_mapping => { '@PATH_TO_SOURCES@' => '@TEMP_SAMPLES_DIR@' },
);

my $src = Code::CovTool::Sources->new( src_dir => $samples_dir );
my $cov = Code::CovTool->new( src => $src, file => "$samples_dir/simple_nested.lcov" );

=head1 GROUP: Методы
=head1 SUBGROUP: clone
=head1 TYPE: Негативные
=head1 TEST: Метод не принимает никаких аргументов
=cut
subtest 'Метод не принимает никаких аргументов' => sub {
  throws_ok { $cov->clone( 'some_arg' ) } qr/ERROR: clone\(\) does not take any arguments/;
};

=head1 GROUP: Методы
=head1 SUBGROUP: clone
=head1 TYPE: Позитивные
=head1 TEST: Вернет копию существующего экземпляра класса Code::CovTool
=cut
subtest 'Вернет копию существующего экземпляра класса Code::CovTool' => sub {
  my $cloned = $cov->clone();

  isnt refaddr($cloned), refaddr($cov), 'возвращён новый объект (другой экземпляр)';
  isa_ok( $cloned, 'Code::CovTool', 'возвращён экземпляр Code::CovTool' );

  my @orig_files = @{ $cov->get_file_list };
  my @cloned_files = @{ $cloned->get_file_list };
  is scalar @cloned_files, scalar @orig_files, 'в копии то же количество файлов';
  is_deeply [ sort @cloned_files ], [ sort @orig_files ], 'список файлов совпадает';

  my $orig_parsed   = Local::Test::Helper::lcov2simple_hash( $cov->export );
  my $cloned_parsed = Local::Test::Helper::lcov2simple_hash( $cloned->export );
  is_deeply( $cloned_parsed, $orig_parsed, 'покрытие в копии идентично исходному' );
};

done_testing;
