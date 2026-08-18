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
=head1 SUBGROUP: append
=head1 TYPE: Негативные
=head1 TEST: На вход может принимать только объект Code::CovTool
=cut
subtest 'На вход может принимать только объект Code::CovTool' => sub {
    my $total = Code::CovTool->new( src => $src );
    my $bad_obj = bless {}, 'Test';
    throws_ok(
        sub {
            $total->append( $bad_obj )
        }, qr /class does not match, should be Code::CovTool/
    );
};

=head1 GROUP: Методы
=head1 SUBGROUP: append
=head1 TYPE: Позитивные
=head1 TEST: При добавлении пустого покрытия к пустому получаем пустое покрытие. 
=cut
subtest 'При добавлении пустого покрытия к пустому получаем пустое покрытие.' => sub {
    my $total    = Code::CovTool->new( src => $src );
    my $empty    = Code::CovTool->new( src => $src );
    my $expected = '';
    is $total->export, $expected;
};

=head1 GROUP: Методы
=head1 SUBGROUP: append
=head1 TYPE: Позитивные
=head1 TEST: При добавлении к пустому покрытию непустого получаем идентичное непустое. 
=cut
subtest 'При добавлении к пустому покрытию непустого получаем идентичное непустое.' => sub {
    my $total = Code::CovTool->new( src => $src );
    my $f1    = Code::CovTool->new( src => $src, file => "$samples_dir/simple.lcov" );

    $total->append( $f1 );

    my $total_export = Local::Test::Helper::lcov2simple_hash( $total->export );

    is_deeply( [ Local::Test::Helper::calculate_cov( $total_export ) ], [ 2, 6, 27 ] );
};

=head1 GROUP: Методы
=head1 SUBGROUP: append
=head1 TYPE: Позитивные
=head1 TEST: При сложении непустых непересекающихся покрытий (на разных файлах) покрытия объединяются. 
=cut
subtest 'При сложении непустых непересекающихся покрытий (на разных файлах) покрытия объединяются.' => sub {
    my $total = Code::CovTool->new( src => $src );

    my $f1  = Code::CovTool->new(
      src  => $src,
      file => "$samples_dir/simple.lcov"
    );

    my $f2  = Code::CovTool->new(
      src  => $src,
      file => "$samples_dir/special_cases.lcov"
    );

    $total->append( $f1 );
    $total->append( $f2 );

    my $f1_export = Local::Test::Helper::lcov2simple_hash( $f1->export );
    # покрытие f1
    is_deeply( [ Local::Test::Helper::calculate_cov( $f1_export ) ], [ 2, 6, 27 ] );

    my $f2_export = Local::Test::Helper::lcov2simple_hash( $f2->export );
    # покрытие f2
    is_deeply( [ Local::Test::Helper::calculate_cov( $f2_export ) ], [ 1, 2, 11 ] );

    my $total_export = Local::Test::Helper::lcov2simple_hash( $total->export );

    is_deeply( [ Local::Test::Helper::calculate_cov( $total_export ) ], [ 3, 8, 38 ] )
};

=head1 GROUP: Методы
=head1 SUBGROUP: append
=head1 TYPE: Позитивные
=head1 TEST: При сложении непустых пересекающихся покрытий (часть файлов совпадают), непересекающиеся файлы объединяются, пересекающиеся файлы суммируются.
=cut
subtest 'При сложении непустых пересекающихся покрытий (часть файлов совпадают), непересекающиеся файлы объединяются, пересекающиеся файлы суммируются.' => sub {
    my $total = Code::CovTool->new( src => $src );

    my $f1  = Code::CovTool->new(
      src  => $src,
      file => "$samples_dir/simple.lcov"
    );

    my $f2  = Code::CovTool->new(
      src  => $src,
      file => "$samples_dir/full.lcov"
    );

    my $f3  = Code::CovTool->new(
      src  => $src,
      file => "$samples_dir/special_cases.lcov"
    );

    $total->append( $f1 );
    $total->append( $f2 );

    my $f1_export = Local::Test::Helper::lcov2simple_hash( $f1->export );
    # покрытие f1
    is_deeply( [ Local::Test::Helper::calculate_cov( $f1_export ) ], [ 2, 6, 27 ] );

    my $f2_export = Local::Test::Helper::lcov2simple_hash( $f2->export );
    # покрытие f2 (точно такое же, только покрыто больше)
    is_deeply( [ Local::Test::Helper::calculate_cov( $f2_export ) ], [ 2, 6, 27 ] );

    my $total_export = Local::Test::Helper::lcov2simple_hash( $total->export );
    is_deeply( [ Local::Test::Helper::calculate_cov( $total_export ) ], [ 2, 6, 27 ] );
    is keys %$total_export, 2, 'всего 2 файла в покрытии';

    $total->append( $f3 );

    my $f3_export = Local::Test::Helper::lcov2simple_hash( $f3->export );
    is_deeply( [ Local::Test::Helper::calculate_cov( $f3_export ) ], [ 1, 2, 11 ] );

    # суммарное
    my $total_export = Local::Test::Helper::lcov2simple_hash( $total->export );
    is keys %$total_export, 3, 'всего 3 файла в покрытии';
    is_deeply( [ Local::Test::Helper::calculate_cov( $total_export ) ], [ 3, 8, 38 ] );
};

done_testing;
