use strict;
use FindBin;
use File::Spec;
use Path::Tiny;
# Основные
use lib $FindBin::Bin."/../lib";
# Хелпер
use lib $FindBin::Bin."/lib";

use Test::Exception;
use Test::More;

# base setup
my $abs_path    = Cwd::abs_path( $0 );
my $current_dir = File::Basename::dirname( $abs_path );
my $temp_dir    = Path::Tiny->tempdir( 'lcov_test_XXXX' );

use_ok('Code::CovTool');
use_ok('Code::CovTool::Sources');

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: Конфликтующие checksum
=cut
subtest 'Конфликтующие checksum' => sub {
    use Local::Test::Helper;

    my $samples_dir = Local::Test::Helper::prepare_samples_dir(
      path_mapping => { '@PATH_TO_SOURCES@' => '@TEMP_SAMPLES_DIR@' },
    );

    my $src = Code::CovTool::Sources->new( src_dir => $samples_dir );

    throws_ok {
        my $checksum_conflict = Code::CovTool->new(
            src  => $src,
            file => "$samples_dir/checksum_conflict.lcov",
        );
    } qr/ERROR: checksum mismatch/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: src должен быть обязательно указан
=cut
subtest 'src должен быть обязательно указан' => sub {
    my @lines = (
        'SF:src/file.c',
        'DA:1,1',
        'end_of_record'
    );

    my $file = $temp_dir->child( 'ok.lcov' );
    $file->spew( join "\n", @lines );

    my $src_dir = $temp_dir->child('src');
    $src_dir->mkpath;

    my $src_file = $src_dir->child( 'file.c' );
    $src_file->spew( 'test' );

    throws_ok {
        my $cov = Code::CovTool->new(
            file => $file->stringify,
        )
    } qr/Attribute \(src\) is required at/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: file не может быть пустой строкой
=cut
subtest 'file не может быть пустой строкой' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    throws_ok {
        my $cov = Code::CovTool->new( src => $src, file => '' )
    } qr /ERROR: cannot open file/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: file должен существовать
=cut
subtest 'file должен существовать' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );

    throws_ok {
        my $cov = Code::CovTool->new(
            src  => $src,
            file => "$temp_dir/not_found.lcov",
        )
    } qr/ERROR: cannot open file .*not_found.lcov: No such file or directory/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: в файле lcov, не должно быть не опознаных полей
=cut
subtest 'в файле lcov, не должно быть не опознаных полей' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @lines = (
        "SF:$temp_dir/file.c",
        'BAD_COLUMN:VAL',
        'end_of_record'
    );

    my $not_found = $temp_dir->child( 'bad_format.lcov' );
    $not_found->spew( join "\n", @lines );

    my $src_file = $temp_dir->child( 'file.c' );
    $src_file->spew( 'test' );

    throws_ok {
        my $cov = Code::CovTool->new(
            src  => $src,
            file => $not_found->stringify,
        )
    } qr /Unknown line format/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: в файле lcov, обязательно должен быть указан SF
=cut
subtest 'в файле lcov, обязательно должен быть указан SF' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @lines = (
        'DA:1,1',
        'end_of_record',
    );

    my $file = $temp_dir->child( 'no_sf.lcov' );
    $file->spew( join "\n", @lines );

    throws_ok {
        my $cov = Code::CovTool->new(
            src  => $src,
            file => $file->stringify,
        )
    } qr/ERROR:.*: Data outside of record \(missing SF\?\)/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: в файле lcov, должен присутствовать закрывающий тег - end_of_record
=cut
subtest 'в файле lcov, должен присутствовать закрывающий тег - end_of_record' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @lines = (
        'SF:file.c',
        'DA:1,1',
    );

    my $file = $temp_dir->child( 'unclosed.lcov' );
    $file->spew( join "\n", @lines );

    throws_ok {
        my $cov = Code::CovTool->new(
            src  => $src,
            file => $file->stringify,
        )
    } qr/ERROR:.*: File ends in the middle of record/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: в файле lcov, DA - не соответствует формату
=cut
subtest 'в файле lcov, DA - не соответствует формату' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @lines = (
        'SF:file.c',
        'DA:1,invalid',
        'end_of_record',
    );

    my $file = $temp_dir->child( 'bad_da.lcov' );
    $file->spew( join "\n", @lines );

    throws_ok {
        my $cov = Code::CovTool->new(
            src  => $src,
            file => $file->stringify,
        )
    } qr/ERROR:.*: Invalid DA format/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: в файле lcov, FN - не соответствует формату
=cut
subtest 'в файле lcov, FN - не соответствует формату' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @lines = (
        'SF:file.c',
        'FN:1',
        'end_of_record',
    );

    my $file = $temp_dir->child( 'bad_fn.lcov' );
    $file->spew( join "\n", @lines );

    throws_ok {
        my $cov = Code::CovTool->new(
            src  => $src,
            file => $file->stringify,
        )
    } qr/ERROR:.*: Invalid FN format/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: в файле lcov, FNDA - не соответствует формату
=cut
subtest 'в файле lcov, FNDA - не соответствует формату' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @lines = (
        'SF:file.c',
        'FN:1,func1',
        'FNDA:invalid,func1',
        'end_of_record',
    );

    my $file = $temp_dir->child( 'bad_fnda.lcov' );
    $file->spew( join "\n", @lines );

    throws_ok {
        my $cov = Code::CovTool->new(
            src  => $src,
            file => $file->stringify,
        )
    } qr/ERROR:.*: Invalid FNDA format/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: в файле lcov, BRDA - не соответствует формату
=cut
subtest 'в файле lcov, BRDA - не соответствует формату' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @lines = (
        'SF:file.c',
        'BRDA:1,0,0,invalid',
        'end_of_record',
    );

    my $file = $temp_dir->child( 'bad_brda.lcov' );
    $file->spew( join "\n", @lines );

    throws_ok {
        my $cov = Code::CovTool->new(
            src  => $src,
            file => $file->stringify,
        )
    } qr/ERROR:.*: Invalid BRDA format/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: в файле lcov, суммарные поля - не соответствуют формату
=cut
subtest 'в файле lcov, суммарные поля - не соответствуют формату' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @metrics = qw( LF LH FNF FNH BRF BRH );
    foreach my $metric ( @metrics ) {
        my @lines = (
            'SF:file.c',
            "$metric:invalid",
            'end_of_record',
        );

        my $file = $temp_dir->child( 'bad_metric.lcov' );
        $file->spew( join "\n", @lines );

        throws_ok {
            my $cov = Code::CovTool->new(
                src  => $src,
                file => $file->stringify,
            )
        } qr/ERROR:.*: Invalid metric $metric format/;
    }
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: указанный внутри LCOV файл в строке S[K|F] должен существовать в source tree
=cut
subtest 'указанный внутри LCOV файл в строке S[K|F] должен существовать в source tree' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @lines = (
        "SF:$temp_dir/notfound.c",
        'DA:1,1',
        'end_of_record'
    );

    my $not_found = $temp_dir->child( 'not_found.lcov' );
    $not_found->spew( join "\n", @lines );

    throws_ok {
        my $cov = Code::CovTool->new(
            src  => $src,
            file => $not_found->stringify,
        )
    } qr /\[ln: \d+\] File does not exist/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Негативные
=head1 TEST: указанный внутри LCOV файл в строке S[K|F] не должен находиться за пределами source tree
=cut
subtest 'указанный внутри LCOV файл в строке S[K|F] не должен находиться за пределами source tree' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my $outside_dir = Path::Tiny->tempdir( 'lcov_test_XXXX' );

    my @lines = (
        "SF:$outside_dir/file.c",
        'DA:1,1',
        'end_of_record'
    );

    my $outside = $temp_dir->child( 'outside_src.lcov' );
    $outside->spew( join "\n", @lines );
 
    my $src_file = $outside_dir->child( 'file.c' );
    $src_file->spew( 'test' );

    throws_ok {
        my $cov = Code::CovTool->new(
            src  => $src,
            file => $outside->stringify,
        )
    } qr /\[ln: \d+\] File is outside source tree/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Позитивные
=head1 TEST: успешная инициализация с комментариями и пустыми строками
=cut
subtest 'успешная инициализация с комментариями и пустыми строками' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @lines = (
        '# Comment line',
        "\n",
        'SF:file.c',
        'DA:1,1',
        "\n",
        'end_of_record',
    );

    my $file = $temp_dir->child( 'comments.lcov' );
    $file->spew( join "\n", @lines );

    my $cov;
    lives_ok {
        $cov = Code::CovTool->new( src => $src, file => $file->stringify )
    };

    isa_ok( $cov, 'Code::CovTool' );
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Позитивные
=head1 TEST: успешная инициализация с несколькоми записями в одном файле
=cut
subtest 'успешная инициализация с несколькоми записями в одном файле' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @lines = (
        'SF:src/multi_file1.c',
        'DA:1,1',
        'end_of_record',
        'SF:src/multi_file2.c',
        'DA:2,1',
        'end_of_record',
    );

    my $file = $temp_dir->child( 'multiple.lcov' );
    $file->spew( join "\n", @lines );

    my $src_dir = $temp_dir->child('src');
    $src_dir->mkpath;

    my $src_file1 = $src_dir->child( 'multi_file1.c' );
    $src_file1->spew( 'test' );

    my $src_file2 = $src_dir->child( 'multi_file2.c' );
    $src_file2->spew( 'test' );

    my $cov;
    lives_ok {
        $cov = Code::CovTool->new( src => $src, file => $file->stringify )
    };

    isa_ok( $cov, 'Code::CovTool' );
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Позитивные
=head1 TEST: успешная инициализация с FNDA без FN
=cut
subtest 'успешная инициализация с FNDA без FN' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @lines = (
        'SF:file.c',
        'FNDA:1,func1',
        'end_of_record',
    );

    my $file = $temp_dir->child( 'fnda_without_fn.lcov' );
    $file->spew( join "\n", @lines );

    my $cov;
    lives_ok {
        $cov = Code::CovTool->new( src => $src, file => $file->stringify )
    };

    isa_ok( $cov, 'Code::CovTool' );
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Позитивные
=head1 TEST: успешная инициализация с src и file (c относительным путем) в конструкторе
=cut
subtest 'успешная инициализация с src и file (c относительным путем) в конструкторе' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @lines = (
        'SF:src/file.c',
        'DA:1,1',
        'end_of_record'
    );

    my $file = $temp_dir->child( 'ok_sf_relative_paths.lcov' );
    $file->spew( join "\n", @lines );

    my $src_dir = $temp_dir->child('src');
    $src_dir->mkpath;

    my $src_file = $src_dir->child( 'file.c' );
    $src_file->spew( 'test' );

    my $cov;
    lives_ok {
        $cov = Code::CovTool->new( src => $src, file => $file->stringify )
    };

    isa_ok( $cov, 'Code::CovTool' );
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Позитивные
=head1 TEST: успешная инициализация с src и file (c абсолютным путем) в конструкторе
=cut
subtest 'успешная инициализация с src и file (c абсолютным путем) в конструкторе' => sub {
    my $src = Code::CovTool::Sources->new( src_dir => "$temp_dir" );
    my @lines = (
        "SF:$temp_dir/file.c",
        'DA:1,1',
        'end_of_record'
    );

    my $file = $temp_dir->child( 'ok_sf_absolute_paths.lcov' );
    $file->spew( join "\n", @lines );

    my $src_file = $temp_dir->child( 'file.c' );
    $src_file->spew( 'test' );

    my $cov;
    lives_ok {
        $cov = Code::CovTool->new( src => $src, file => $file->stringify )
    };

    isa_ok( $cov, 'Code::CovTool' );
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool
=head1 TYPE: Позитивные
=head1 TEST: успешная инициализация без file, необходимо для суммирования
=cut
subtest 'успешная инициализация без file, необходимо для суммирования' => sub {
    my $cov = Code::CovTool->new( src => Code::CovTool::Sources->new( src_dir => "$temp_dir" ) );
    isa_ok( $cov, 'Code::CovTool' );
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool::Sources
=head1 TYPE: Негативные
=head1 TEST: пустой конструктор вызывает ошибку
=cut
subtest 'пустой конструктор вызывает ошибку' => sub {
    throws_ok {
        my $src = Code::CovTool::Sources->new()
    } qr/\(src_dir\) is required at.*/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool::Sources
=head1 TYPE: Негативные
=head1 TEST: src_dir должна существовать
=cut
subtest 'src_dir должна существовать' => sub {
    throws_ok {
        my $src = Code::CovTool::Sources->new( src_dir => '/test'  )
    } qr/Directory \/test does not exist.*/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool::Sources
=head1 TYPE: Негативные
=head1 TEST: src_dir не может быть пустой
=cut
subtest 'src_dir не может быть пустой' => sub {
    throws_ok {
        my $src = Code::CovTool::Sources->new( src_dir => '' )
    } qr/Directory path cannot be empty/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool::Sources
=head1 TYPE: Негативные
=head1 TEST: src_dir объект должен быть Path::Tiny
=cut
subtest 'src_dir объект должен быть Path::Tiny' => sub {
    my $invalid_obj = bless {}, 'Local::NotPathTiny';

    throws_ok {
        my $src = Code::CovTool::Sources->new( src_dir => $invalid_obj );
    } qr/src_dir object must be Path::Tiny/;
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool::Sources
=head1 TYPE: Позитивные
=head1 TEST: абсолютные SF-пути принимаются при src_dir='/'
=cut
subtest "абсолютные SF-пути принимаются при src_dir='/'" => sub {
    use Local::Test::Helper;

    my $samples_dir = Local::Test::Helper::prepare_samples_dir(
      path_mapping => { '@PATH_TO_SOURCES@' => '@TEMP_SAMPLES_DIR@' },
    );

    my $src_root = Code::CovTool::Sources->new( src_dir => '/' );

    lives_ok {
      my $cov = Code::CovTool->new(
        src  => $src_root,
        file => "$samples_dir/simple.lcov",
      );
      ok( !$cov->is_empty, 'parsed coverage is not empty' );
    };
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool::Sources
=head1 TYPE: Позитивные
=head1 TEST: успешная инициализация с src_dir в конструкторе
=cut
subtest 'успешная инициализация с src_dir в конструкторе' => sub {
    my $src;
    my $test_dir    = $FindBin::Bin;
    my $samples_dir = File::Spec->catdir( $test_dir, 'samples' );

    lives_ok {
        $src = Code::CovTool::Sources->new( src_dir => $samples_dir );
    };
    isa_ok( $src, 'Code::CovTool::Sources' );
};

=head1 GROUP: Инициализация объектов
=head1 SUBGROUP: Code::CovTool::Sources
=head1 TYPE: Позитивные
=head1 TEST: успешная инициализация с src_dir как Path::Tiny
=cut
subtest 'успешная инициализация с src_dir как Path::Tiny' => sub {
    my $src;
    my $test_dir    = $FindBin::Bin;
    my $samples_dir = path( File::Spec->catdir( $test_dir, 'samples' ) );

    lives_ok {
        $src = Code::CovTool::Sources->new( src_dir => $samples_dir );
    };
    isa_ok( $src, 'Code::CovTool::Sources' );
    is( $src->src_dir, $samples_dir->stringify, 'Path::Tiny корректно приведен к строке пути' );
};

done_testing;
