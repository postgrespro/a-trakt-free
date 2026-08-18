use strict;
use FindBin;
use Path::Tiny;
use File::Path qw( remove_tree );
# Основные
use lib $FindBin::Bin."/../lib";
# Хелпер
use lib $FindBin::Bin."/lib";

use Test::Exception;
use Test::More;

use Code::CovTool;
use Code::CovTool::Sources;

#Base
use Local::Test::Helper;

my $samples_dir = Local::Test::Helper::prepare_samples_dir(
  path_mapping => { '@PATH_TO_SOURCES@' => '@TEMP_SAMPLES_DIR@' },
);

# FIXME: В будущем надо переделать метод get_function_info для работы с манглированными именами.

my $src = Code::CovTool::Sources->new( src_dir => $samples_dir );
my $cov = Code::CovTool->new( src => $src, file => "$samples_dir/simple.lcov" );

=head1 GROUP: Методы
=head1 SUBGROUP: get_function_info
=head1 TYPE: Негативные
=head1 TEST: должно вызвать die если функция не нашлось в текущем покрытии
=cut
subtest 'должно вызвать die если функция не нашлось в текущем покрытии' => sub {
  throws_ok { $cov->get_function_info( 'test' ) } qr /function not found in current coverage/;
};

=head1 GROUP: Методы
=head1 SUBGROUP: get_function_info
=head1 TYPE: Позитивые
=head1 TEST: должен вернуть arrayref с hashref ( { filename => ... , start_line => ... } )
=cut
subtest 'должен вернуть arrayref с hashref ( { filename => ... , start_line => ... } )' => sub {
  my $actual   = $cov->get_function_info( 'simple_math' );
  my $expected = {
    simple_math => [
      {
        filename   => $samples_dir . '/src/core_functions.c',
        start_line => 4,
      }
    ]
  };

  is_deeply $expected, $actual;
};

done_testing;
