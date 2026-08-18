use strict;
use FindBin;
use Path::Tiny;
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

my $src = Code::CovTool::Sources->new( src_dir => $samples_dir );
my $cov = Code::CovTool->new(
    src  => $src,
    file => "$samples_dir/simple.lcov"
);

=head1 GROUP: Методы
=head1 SUBGROUP: get_function_list
=head1 TYPE: Негативные
=head1 TEST: путь не может быть пустой
=cut
subtest 'путь не может быть пустой' => sub {
    throws_ok {
        $cov->get_function_list( '' )
    } qr/Directory path cannot be empty/;
};

=head1 GROUP: Методы
=head1 SUBGROUP: get_function_list
=head1 TYPE: Негативные
=head1 TEST: путь должен существовать в source tree
=cut
subtest 'путь должен существовать в source tree' => sub {
    throws_ok {
        $cov->get_function_list( 'notfound/catalog' )
    } qr/ERROR: Path \'notfound\/catalog\' does not exist in source tree/;
};

=head1 GROUP: Методы
=head1 SUBGROUP: get_function_list
=head1 TYPE: Позитивные
=head1 TEST: должно вернуть список всех функций в покрытии, если вызвали без метода
=cut
subtest 'должно вернуть список всех функций в покрытии, если вызвали без метода' => sub {
    my $actual   = $cov->get_function_list();
    my $expected = [
        'calculate_sum',
        'check_value',
        'find_max',
        'print_numbers',
        'safe_divide',
        'simple_math'
    ];
    is_deeply $actual, $expected;
};

=head1 GROUP: Методы
=head1 SUBGROUP: get_function_list
=head1 TYPE: Позитивные
=head1 TEST: должно вернуть список функций найденных по пути 'src/' 
=cut
subtest "должно вернуть список функций найденных по пути 'src/'" => sub {
    my $actual  = $cov->get_function_list( 'src/' );
        my $expected = [
        'calculate_sum',
        'check_value',
        'find_max',
        'print_numbers',
        'safe_divide',
        'simple_math'
    ];
    is_deeply $actual, $expected;
};

=head1 GROUP: Методы
=head1 SUBGROUP: get_function_list
=head1 TYPE: Позитивные
=head1 TEST: должно вернуть список функций найденных в конкретном файле 'src/core_functions.c' 
=cut
subtest "должно вернуть список функций найденных в конкретном файле 'src/core_functions.c'" => sub {
    my $actual  = $cov->get_function_list( 'src/core_functions.c' );
        my $expected = [
        'safe_divide',
        'simple_math'
    ];
    is_deeply $actual, $expected;
};

done_testing;
