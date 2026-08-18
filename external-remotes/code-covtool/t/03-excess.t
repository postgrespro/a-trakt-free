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

my %ref_coverage = Local::Test::Helper::get_reference_coverage( $samples_dir );

my $src = Code::CovTool::Sources->new( src_dir => $samples_dir );

=head1 GROUP: Методы
=head1 SUBGROUP: excess
=head1 TYPE: Негативные
=head1 TEST: На вход может принимать только объект Code::CovTool
=cut
subtest 'На вход может принимать только объект Code::CovTool' => sub {
    my $cov = Code::CovTool->new( src => $src, file => "$samples_dir/simple.lcov" );
    my $bad_obj = bless {}, 'Test';
    throws_ok(
        sub {
            $cov->excess( $bad_obj )
        }, qr /class does not match, should be Code::CovTool/
    );
    throws_ok(
        sub {
            $cov < $bad_obj
        }, qr /class does not match, should be Code::CovTool/
    );
};


=head1 GROUP: Методы
=head1 SUBGROUP: excess
=head1 TYPE: Позитивные
=head1 TEST: должно вернуть новый объект Code::CovTool с покрытием в которое входят все строки f2 которых нет в f1
=cut
subtest 'должно вернуть новый объект Code::CovTool с покрытием в которое входят все строки f2 которых нет в f1' => sub {
    my $f1 = Code::CovTool->new(
        src  => $src,
        file => "$samples_dir/simple.lcov"
    );

    my $f1_export          = Local::Test::Helper::lcov2simple_hash( $f1->export );
    my $expected_f1_export = $ref_coverage{'simple.lcov'};

    is_deeply ( $expected_f1_export, $f1_export );

    my $f2 = Code::CovTool->new(
        src  => $src,
        file => "$samples_dir/full.lcov"
    );

    my $f2_export          = Local::Test::Helper::lcov2simple_hash( $f2->export );
    my $expected_f2_export = $ref_coverage{'full.lcov'};

    is_deeply( $expected_f2_export, $f2_export );

    my $excess = $f1->excess( $f2 );
    my $excess_export = Local::Test::Helper::lcov2simple_hash( $excess->export );

    my $excess_overload = $f1 < $f2;
    my $excess_overload_export = Local::Test::Helper::lcov2simple_hash( $excess_overload->export );

    my $expected_excess_export = {
      "$samples_dir/src/core_functions.c" => {
        SF  => "$samples_dir/src/core_functions.c",
        FNF => '2',
        # - покрытые строки из f1 ( 5 - 2 )
        LH  => '3',
        # 4,5 были в f1
        DA  => {
          10 => '1',
          4  => '0',
          5  => '0',
          8  => '1',
          9  => '1',
        },
        FNH => '2',
        FN  => {
          simple_math => '4',
          safe_divide => '8',
        },
        LF   => '5',
        # simple_math было в f1
        FNDA => {
          safe_divide  => '500',
          simple_math  => '5000',
        },
      },
      "$samples_dir/src/advanced_coverage.c" => {
        FNH => '4',
        FN  => {
          find_max      => '12',
          calculate_sum => '20',
          print_numbers => '28',
          check_value   => '5',
        },
        LF   => '22',
        # find_max, print_numbers - были в f1
        FNDA => {
          find_max      => '500',
          print_numbers => '500',
          calculate_sum => '5000',
          check_value   => '5000',
        },
        SF  => "$samples_dir/src/advanced_coverage.c",
        FNF => '4',
        # - покрытые строки из f1 ( 22 - 9 )
        LH  => '13',
        # 20-25, 5-8 были в f1,
        DA  => {
          12 => '1',
          13 => '1',
          14 => '1',
          15 => '1',
          16 => '1',
          20 => '0',
          21 => '0',
          22 => '0',
          23 => '0',
          25 => '0',
          28 => '1',
          29 => '5',
          30 => '4',
          31 => '2',
          33 => '2',
          36 => '1',
          37 => '1',
          5  => '0',
          6  => '0',
          7  => '0',
          8  => '0',
          9  => '1',
        },
      },
    };

    is_deeply( $expected_excess_export, $excess_export );
    is_deeply( $expected_excess_export, $excess_overload_export);
};

done_testing;
