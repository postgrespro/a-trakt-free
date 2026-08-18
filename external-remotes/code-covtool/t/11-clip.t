use strict;
use warnings;
use FindBin;
use File::Path qw( make_path remove_tree );
use File::Spec;
use Path::Tiny qw( path );
use Scalar::Util qw( refaddr );
use lib $FindBin::Bin."/../lib";
use lib $FindBin::Bin."/lib";

use Test::Exception;
use Test::More;

use Code::CovTool;
use Code::CovTool::Sources;
use Local::Test::Helper qw(
  build_cov_from_file
  build_matrix_clip_case_cov
  assert_lcov_eq
  expected_lcov_path
  rel_to_abs_path
  test_warn_ok
);

my $samples_dir = Local::Test::Helper::prepare_samples_dir(
  path_mapping => { '@PATH_TO_SOURCES@' => '@TEMP_SAMPLES_DIR@' },
);

my $src  = Code::CovTool::Sources->new( src_dir => $samples_dir );
my $lcov = "$samples_dir/clip_plan.lcov";

my @ROOT_SRC_ONE  = qw( src/core_functions.c );
my @ROOT_SRC_TWO  = qw( src/core_functions.c src/main.c );
my @ROOT_SRC_MANY = qw( src/core_functions.c src/main.c src/advanced_coverage.c src/special_cases.c );
my @SUB_SRC_ONE   = qw( src/flat_one/only.c );
my @SUB_SRC_TWO   = qw( src/flat_two/a.c src/flat_two/b.c );
my @SUB_SRC_MANY  = qw( src/flat_many/x1.c src/flat_many/x2.c src/flat_many/x3.c );
my @ROOT_SRC_ONE_SUB_SRC_MANY = ( @ROOT_SRC_ONE, @SUB_SRC_MANY );
my @TEMPLATE_ONE  = qw( src/flat_one/only.c );
my @TEMPLATE_TWO  = qw( src/flat_two/a.c src/flat_two/b.c );
my @TEMPLATE_MANY = qw( src/flat_many/x1.c src/flat_many/x2.c src/flat_many/x3.c );

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Негативные
=head1 TEST: Вызов без аргументов
=cut
subtest 'Вызов без аргументов' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  throws_ok { $cov->clip() }
    qr/ERROR: Expected single path \(string\) or \( files => \\\@paths \)/;
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: В { files => [] } должны быть удалены все файлы, на выходе пустое покрытие
=cut
subtest 'В { files => [] } должны быть удалены все файлы, на выходе пустое покрытие' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $clipped = $cov->clip( files => [] );
  my $parsed = Local::Test::Helper::lcov2simple_hash( $clipped->export );
  is( scalar keys %$parsed, 0, 'после clip(files=>[]) SF отсутствуют' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: clip возвращает новый экземпляр во всех случаях
=cut
subtest 'clip возвращает новый экземпляр во всех случаях' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @cases = (
    [ 'пустой список', sub { $cov->clip( files => [] ) } ],
    [ 'одиночный файл', sub { $cov->clip('src/flat_one/only.c') } ],
    [
      'список файлов',
      sub { $cov->clip( files => [ 'src/flat_one/only.c', 'src/backend/utils' ] ) },
    ],
  );
  for my $c ( @cases ) {
    my ( $label, $call ) = @$c;
    my $clipped = $call->();
    isnt refaddr($clipped), refaddr($cov), "$label: возвращен новый объект";
  }
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход пустую папку, на выходе пустое покрытие
=cut
subtest 'Передаем на вход пустую папку, на выходе пустое покрытие' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $empty = File::Spec->catfile( $samples_dir, 'src', 'empty_clip' );
  make_path($empty);
  my $clipped = $cov->clip('src/empty_clip');
  my $parsed = Local::Test::Helper::lcov2simple_hash( $clipped->export );
  is( scalar keys %$parsed, 0, 'после clip(пустая папка) SF отсутствуют' );
  remove_tree($empty);
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files => один файл, он лежит в корне }
=cut
subtest 'Передаем на вход в { files => один файл, он лежит в корне }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $clipped = $cov->clip( $ROOT_SRC_ONE[0] );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'root_one_file.lcov' ),
    'остался только нужный SF',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files => два файла, они лежат в корне }
=cut
subtest 'Передаем на вход в { files => два файла, они лежат в корне }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $clipped = $cov->clip( files => [ @ROOT_SRC_TWO ] );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'root_two_files.lcov' ),
    'два файла из корня',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files => много файлов, они лежат в корне }
=cut
subtest 'Передаем на вход в { files => много файлов, они лежат в корне }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $clipped = $cov->clip( files => [ @ROOT_SRC_MANY ] );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'root_many_files.lcov' ),
    'много файлов из корня',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files => один файл в корне + несколько файлов в подпапке }
=cut
subtest 'Передаем на вход в { files => один файл в корне + несколько файлов в подпапке }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $clipped = $cov->clip( files => [ @ROOT_SRC_ONE_SUB_SRC_MANY ] );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'root_one_plus_sub_many.lcov' ),
    'смешанный список: корень + подпапка',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files => один файл, он лежит в подпапке }
=cut
subtest 'Передаем на вход в { files => один файл, он лежит в подпапке }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $clipped = $cov->clip( $SUB_SRC_ONE[0] );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'sub_one_file.lcov' ),
    'один файл из подпапки',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files => два файла, они лежат в подпапке }
=cut
subtest 'Передаем на вход в { files => два файла, они лежат в подпапке }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $clipped = $cov->clip( files => [ @SUB_SRC_TWO ] );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'sub_two_files.lcov' ),
    'два файла из подпапки',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files => много файлов, они лежат в подпапке }
=cut
subtest 'Передаем на вход в { files => много файлов, они лежат в подпапке }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $clipped = $cov->clip( files => [ @SUB_SRC_MANY ] );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'sub_many_files.lcov' ),
    'много файлов из подпапки',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files =>  папка без под подпапок }
=cut
subtest 'Передаем на вход в { files =>  папка без под подпапок }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $clipped = $cov->clip('src/flat_two');
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'flat_two_dir.lcov' ),
    'папка без подпапок',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files =>  папку с подпапками }
=cut
subtest 'Передаем на вход в { files =>  папку с подпапками }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $clipped = $cov->clip('src/backend');
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'backend_dir.lcov' ),
    'папка с подпапками',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files =>  папку с подпапками, в подпапке лежит много файлов }
=cut
subtest 'Передаем на вход в { files =>  папку с подпапками, в подпапке лежит много файлов }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $clipped = $cov->clip('src/backend/utils');
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'backend_utils_dir.lcov' ),
    'папка с подпапками и множеством файлов',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Матрица кейсов для папок/подпапок
=cut
subtest 'Матрица кейсов для папок/подпапок' => sub {
  my @cases = (
    [ 'SNGL_FLDR_ONE',          'matrix_sngl_fldr_one',         \@TEMPLATE_ONE,  [] ],
    [ 'SNGL_FLDR_TWO',          'matrix_sngl_fldr_two',         \@TEMPLATE_TWO,  [] ],
    [ 'SNGL_FLDR_MANY',         'matrix_sngl_fldr_many',        \@TEMPLATE_MANY, [] ],
    [ 'FLDR_EMPTY-SUB_EMPTY',   'matrix_fldr_empty_sub_empty',  [],              [] ],
    [ 'FLDR_EMPTY-SUB_ONE',     'matrix_fldr_empty_sub_one',    [],              \@TEMPLATE_ONE ],
    [ 'FLDR_EMPTY-SUB_TWO',     'matrix_fldr_empty_sub_two',    [],              \@TEMPLATE_TWO ],
    [ 'FLDR_EMPTY-SUB_MANY',    'matrix_fldr_empty_sub_many',   [],              \@TEMPLATE_MANY ],
    [ 'FLDR_ONE-SUB_EMPTY',     'matrix_fldr_one_sub_empty',    \@TEMPLATE_ONE,  [] ],
    [ 'FLDR_TWO-SUB_EMPTY',     'matrix_fldr_two_sub_empty',    \@TEMPLATE_TWO,  [] ],
    [ 'FLDR_MANY-SUB_EMPTY',    'matrix_fldr_many_sub_empty',   \@TEMPLATE_MANY, [] ],
    [ 'FLDR_ONE-SUB_MANY',      'matrix_fldr_one_sub_many',     \@TEMPLATE_ONE,  \@TEMPLATE_MANY ],
  );

  for my $c ( @cases ) {
    my ( $label, $slug, $root_rels, $sub_rels ) = @$c;
    my ( $cov, $case_rel ) = build_matrix_clip_case_cov( $src, $lcov, $samples_dir, $slug, $root_rels, $sub_rels );
    my $clipped = $cov->clip($case_rel);
    assert_lcov_eq(
      $clipped->export,
      expected_lcov_path( $samples_dir, 'clip', "$slug.lcov" ),
      "matrix: $label",
    );
  }
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: В { files => [] } были переданы явные дубликаты, они не приводят к ошибке, дедуплицируются и выводит warning о дубликатах
=cut
subtest 'В { files => [] } были переданы явные дубликаты, они не приводят к ошибке, дедуплицируются и выводит warning о дубликатах' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @input = qw( src/core_functions.c src/core_functions.c );
  my $clipped;
  test_warn_ok(
    sub { $clipped = $cov->clip( files => \@input ) },
    qr/WARNING: duplicate path/ms,
  );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'duplicate_explicit_paths.lcov' ),
    'явные дубликаты: остается один SF',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: В { files => [] } был передан неявный дубликат (папка + файл внутри неё), он дедуплицируется и выводит warning о дубликате
=cut
subtest 'В { files => [] } был передан неявный дубликат (папка + файл внутри неё), он дедуплицируется и выводит warning о дубликате' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @input = qw( src/backend/utils src/backend/utils/main_simple.c );
  my $clipped;
  test_warn_ok(
    sub { $clipped = $cov->clip( files => \@input ) },
    qr/WARNING: redundant path/ms,
  );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'duplicate_implicit_folder_file.lcov' ),
    'неявный дубликат: остается покрытие папки',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: В { files => [] } передали независимые подпапки
=cut
subtest 'В { files => [] } передали независимые подпапки' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @input = qw( src/flat_one src/flat_two );
  my $clipped = $cov->clip( files => \@input );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'independent_subdirs.lcov' ),
    'независимые подпапки',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: В { files => [] } передали вложенные подпапки вместе с папкой
=cut
subtest 'В { files => [] } передали вложенные подпапки вместе с папкой' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @input = qw( src/backend src/backend/utils );
  my $clipped;
  test_warn_ok(
    sub { $clipped = $cov->clip( files => \@input ) },
    qr/WARNING: redundant path/ms,
  );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'nested_backend_and_utils.lcov' ),
    'вложенная папка дедуплицирована к backend',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: В { files => [] } передали список файлов
=cut
subtest 'В { files => [] } передали список файлов' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @in1 = qw( src/core_functions.c src/advanced_coverage.c );
  assert_lcov_eq(
    $cov->clip( files => \@in1 )->export,
    expected_lcov_path( $samples_dir, 'clip', 'list_two_files_root.lcov' ),
    'список файлов: корень',
  );
  my @in2 = qw( src/backend/utils/main_simple.c src/backend/utils/u_extra.c );
  assert_lcov_eq(
    $cov->clip( files => \@in2 )->export,
    expected_lcov_path( $samples_dir, 'clip', 'list_two_files_utils.lcov' ),
    'список файлов: подпапка',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: В { files => [] } передали произвольный файл, папку, подпапку
=cut
subtest 'В { files => [] } передали произвольный файл, папку, подпапку' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @input = qw( src/main.c src/flat_many src/backend/utils );
  my $clipped = $cov->clip( files => \@input );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'mixed_file_dir_subdir.lcov' ),
    'произвольный файл+папка+подпапка',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: В { files => [] } были переданы рекурсивные папки, когда снизу ссылка ссылается на папку сверху.
=cut
subtest 'В { files => [] } были переданы рекурсивные папки, когда снизу ссылка ссылается на папку сверху.' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $mid = File::Spec->catfile( $samples_dir, 'src', 'flat_one', 'mid' );
  make_path($mid);
  my $up = File::Spec->catfile( $mid, 'up' );
  unlink $up if -l $up || -e _;
  my $ok = eval { symlink( '..', $up ); 1 };
  if ( !$ok ) {
    remove_tree($mid);
    plan skip_all => 'symlink not supported';
    return;
  }
  my $clipped = $cov->clip( files => [ 'src/flat_one/mid/up' ] );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'symlink_resolves_flat_one.lcov' ),
    'symlink папка',
  );
  remove_tree($mid);
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Негативные
=head1 TEST: В { files => [] } некорректный элемент списка (undef / пустая строка / несуществующий путь) даёт ожидаемую ошибку
=cut
subtest 'В { files => [] } некорректный элемент списка (undef / пустая строка / несуществующий путь) даёт ожидаемую ошибку' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  throws_ok { $cov->clip( files => [undef] ) } qr/ERROR: Each path must be a non-empty string/;
  throws_ok { $cov->clip( files => [''] ) } qr/ERROR: Each path must be a non-empty string/;
  throws_ok { $cov->clip( files => [ 'src/no_such_file.c' ] ) } qr/ERROR: Path 'src\/no_such_file\.c' does not exist/;
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Развернуть отдельный файл, папку, интерпретируемые как список из одного элемента.
=cut
subtest 'Развернуть отдельный файл, папку, интерпретируемые как список из одного элемента.' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $file_by_string = Local::Test::Helper::lcov2simple_hash(
    $cov->clip('src/core_functions.c')->export
  );
  my $file_by_list = Local::Test::Helper::lcov2simple_hash(
    $cov->clip( files => [ 'src/core_functions.c' ] )->export
  );
  is_deeply( $file_by_string, $file_by_list, 'файл: строка эквивалентна files=>[один элемент]' );

  my $dir_by_string = Local::Test::Helper::lcov2simple_hash(
    $cov->clip('src/backend/utils')->export
  );
  my $dir_by_list = Local::Test::Helper::lcov2simple_hash(
    $cov->clip( files => [ 'src/backend/utils' ] )->export
  );
  is_deeply( $dir_by_string, $dir_by_list, 'папка: строка эквивалентна files=>[один элемент]' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Развернуть и проверить, что clip корректно работает для одного, двух и нескольких дублирующихся SF.
=cut
subtest 'Развернуть и проверить, что clip корректно работает для одного, двух и нескольких дублирующихся SF.' => sub {
  my @cases = (
    [ 'один SF', 'append_simple_core_only', "$samples_dir/simple.lcov" ],
    [ 'два SF-дубля', 'append_duplicate_sf_two_records', "$samples_dir/dublicate_sf_num.lcov" ],
    [
      'несколько SF-дублей',
      'append_duplicate_sf_many_records',
      "$samples_dir/dublicate_sf_num.lcov",
      "$samples_dir/dublicate_sf_num.lcov",
    ],
  );

  for my $case ( @cases ) {
    my ( $label, $slug, @files ) = @$case;
    my $cov = build_cov_from_file( $src, shift @files );
    for my $file ( @files ) {
      my $next = build_cov_from_file( $src, $file );
      $cov->append( $next );
    }
    my $clipped = $cov->clip('src/core_functions.c');
    assert_lcov_eq(
      $clipped->export,
      expected_lcov_path( $samples_dir, 'clip', "$slug.lcov" ),
      "$label: clip оставил только core_functions",
    );
  }
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: clip принимает Code::CovTool::Sources в files и поддерживает строковый корень (.)
=cut
subtest 'clip принимает Code::CovTool::Sources в files и поддерживает строковый корень (.)' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $from_sources = $cov->clip( files => [ $src ] );
  my $orig = Local::Test::Helper::lcov2simple_hash( $cov->export );
  my $got = Local::Test::Helper::lcov2simple_hash( $from_sources->export );
  is_deeply( $got, $orig, 'files => [ $src ] эквивалентно корню и оставляет полное покрытие' );

  my $src_root = Code::CovTool::Sources->new( src_dir => File::Spec->catdir( $samples_dir, 'src' ) );
  my $cov_src_root = build_cov_from_file( $src_root, $lcov );
  my $by_alias = $cov_src_root->clip('.');
  my $base = Local::Test::Helper::lcov2simple_hash( $cov_src_root->export );
  my $alias = Local::Test::Helper::lcov2simple_hash( $by_alias->export );
  is_deeply( $alias, $base, 'строка "." распознана как корень при src_dir=.../src' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: clip принимает Path::Tiny в files
=cut
subtest 'clip принимает Path::Tiny в files' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $pt = path('src/core_functions.c');
  my $clipped = $cov->clip( files => [ $pt ] );
  assert_lcov_eq(
    $clipped->export,
    expected_lcov_path( $samples_dir, 'clip', 'pathtiny_core_functions.lcov' ),
    'Path::Tiny приводит к корректному пути',
  );
};

# ============================================================
# Регрессионные тесты семантики путей резолвера
# Используют отдельную фикстуру resolver_paths.lcov с парой путей,
# имеющих общий префикс (utils / utils_helpers).
# См. раздел "Семантика сопоставления путей" в README.md (раздел clip).
# ============================================================

my $resolver_lcov = "$samples_dir/resolver_paths.lcov";

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Семантика путей: сопоставление по границе компонента (utils не задевает utils_helpers)
=cut
subtest 'Семантика путей: граница компонента (utils vs utils_helpers)' => sub {
  my $cov = build_cov_from_file( $src, $resolver_lcov );
  my $clipped = $cov->clip('src/resolver_test/utils');
  my @after = sort @{ $clipped->get_file_list };
  my $expected = rel_to_abs_path( $samples_dir, 'src/resolver_test/utils/u.c' );
  is_deeply( \@after, [ $expected ],
    'clip(utils): в новом объекте только utils/u.c, utils_helpers/h.c исключён' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Семантика путей: относительный путь эквивалентен абсолютному
=cut
subtest 'Семантика путей: rel ≡ abs' => sub {
  my $cov = build_cov_from_file( $src, $resolver_lcov );
  my $by_rel = Local::Test::Helper::lcov2simple_hash(
    $cov->clip('src/resolver_test/utils/u.c')->export
  );

  my $abs_path = rel_to_abs_path( $samples_dir, 'src/resolver_test/utils/u.c' );
  my $by_abs = Local::Test::Helper::lcov2simple_hash(
    $cov->clip( $abs_path )->export
  );

  is_deeply( $by_rel, $by_abs,
    'clip(rel) и clip(abs) дают одинаковый результат' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: clip
=head1 TYPE: Позитивные
=head1 TEST: Семантика путей: нормализация аргумента (трейлинг-слеш, ./ , ..)
=cut
subtest 'Семантика путей: нормализация аргумента' => sub {
  my @forms = (
    'src/resolver_test/utils',
    'src/resolver_test/utils/',
    'src/resolver_test/./utils',
    'src/resolver_test/utils_helpers/../utils',
  );

  my $cov = build_cov_from_file( $src, $resolver_lcov );
  my $canonical = Local::Test::Helper::lcov2simple_hash(
    $cov->clip( $forms[0] )->export
  );

  for my $form ( @forms[1..$#forms] ) {
    my $result = Local::Test::Helper::lcov2simple_hash(
      $cov->clip( $form )->export
    );
    is_deeply( $result, $canonical, "форма '$form' эквивалентна канонической" );
  }
};

done_testing;
