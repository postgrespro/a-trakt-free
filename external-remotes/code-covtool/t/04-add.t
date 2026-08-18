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

=head1 GROUP: Методы
=head1 SUBGROUP: add
=head1 TYPE: Негативные
=head1 TEST: На вход может принимать только объект Code::CovTool
=cut
subtest 'На вход может принимать только объект Code::CovTool' => sub {
    my $cov = Code::CovTool->new( src => $src, file => "$samples_dir/simple.lcov" );
    my $bad_obj = bless {}, 'Test';
    throws_ok(
        sub {
            $cov->add( $bad_obj )
        }, qr /class does not match, should be Code::CovTool/
    );
    throws_ok(
        sub {
            $cov + $bad_obj
        }, qr /class does not match, should be Code::CovTool/
    );
};

=head1 GROUP: Методы
=head1 SUBGROUP: add
=head1 TYPE: Позитивные
=head1 TEST: должно вернуть новый объект Code::CovTool включающий покрытие f1 + f2
=cut
subtest 'должно вернуть новый объект Code::CovTool включающий покрытие f1 + f2' => sub {
    my $f1 = Code::CovTool->new(
        src  => $src,
        file => "$samples_dir/simple.lcov"
    );

    my $f1_export = Local::Test::Helper::lcov2simple_hash( $f1->export );

    # изначальное покрытие до добавления
    is_deeply( [ Local::Test::Helper::calculate_cov( $f1_export ) ], [ 2, 6, 27 ] );

    my $f2 = Code::CovTool->new(
        src  => $src,
        file => "$samples_dir/special_cases.lcov"
    );

    my $f2_export = Local::Test::Helper::lcov2simple_hash( $f2->export );
    # покрытие что добавляем
    is_deeply( [ Local::Test::Helper::calculate_cov( $f2_export ) ], [ 1, 2, 11 ] );

    my $merged = $f1->add( $f2 );
    my $merged_export = Local::Test::Helper::lcov2simple_hash( $merged->export );

    my $merged_overload = $f1 + $f2;
    my $merged_overload_export = Local::Test::Helper::lcov2simple_hash( $merged_overload->export );

    # после добавления
    is_deeply( [ Local::Test::Helper::calculate_cov( $merged_export ) ], [ 3, 8, 38 ] );
    is_deeply( [ Local::Test::Helper::calculate_cov( $merged_overload_export ) ], [ 3, 8, 38 ] );
};

done_testing;
