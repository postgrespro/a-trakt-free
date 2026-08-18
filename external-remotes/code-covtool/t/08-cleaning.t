use strict;
use warnings;
use FindBin;
use File::Path qw( make_path remove_tree );
use File::Spec;
use Path::Tiny qw( path );
use lib $FindBin::Bin."/../lib";
use lib $FindBin::Bin."/lib";

use Test::Exception;
use Test::More;

use Code::CovTool;
use Code::CovTool::Sources;
use Local::Test::Helper qw(
  build_cov_from_file
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
my @EXPECT_ALL_BACKEND_RELS = qw(
  src/backend/br_solo.c
  src/backend/br_a.c
  src/backend/br_b.c
  src/backend/br_m1.c
  src/backend/br_m2.c
  src/backend/br_m3.c
  src/backend/utils/main_simple.c
  src/backend/utils/u_extra.c
  src/backend/utils/u_more.c
);

my @ROOT_SRC_ONE  = qw( src/core_functions.c );
my @ROOT_SRC_TWO  = qw( src/core_functions.c src/main.c );
my @ROOT_SRC_MANY = qw( src/core_functions.c src/main.c src/advanced_coverage.c src/special_cases.c );
my @SUB_SRC_ONE   = qw( src/flat_one/only.c );
my @SUB_SRC_TWO   = qw( src/flat_two/a.c src/flat_two/b.c );
my @SUB_SRC_MANY  = qw( src/flat_many/x1.c src/flat_many/x2.c src/flat_many/x3.c );

sub _unchanged_assert {
  my ( $before, $after, $msg ) = @_;
  is_deeply( $after, $before, $msg );
}

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Негативные
=head1 TEST: Вызов без аргументов
=cut
subtest 'Вызов без аргументов' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  throws_ok { $cov->cleaning() }
    qr/ERROR: Expected single path \(string\) or \( files => \\\@paths \)/;
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Негативные
=head1 TEST: Несуществующая директория
=cut
subtest 'Несуществующая директория' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  throws_ok { $cov->cleaning( 'src/no_such_dir' ) }
    qr/ERROR: Path 'src\/no_such_dir' does not exist/;
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход пустую папку (warning, покрытие без изменений)
=cut
subtest 'Передаем на вход пустую папку (warning, покрытие без изменений)' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $before = Local::Test::Helper::lcov2simple_hash( $cov->export );
  my $empty = File::Spec->catfile( $samples_dir, 'src', 'empty_cleaning' );
  make_path($empty);
  test_warn_ok(
    sub { $cov->cleaning('src/empty_cleaning') },
    qr/WARNING: No coverage data matches path\(s\): src\/empty_cleaning/ms,
  );
  my $after = Local::Test::Helper::lcov2simple_hash( $cov->export );
  _unchanged_assert( $before, $after, 'cleaning по пустой папке не меняет покрытие' );
  remove_tree($empty);
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Папка с файлами, которых нет в покрытии
=cut
subtest 'Папка с файлами, которых нет в покрытии' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $before = Local::Test::Helper::lcov2simple_hash( $cov->export );
  my $dir = File::Spec->catfile( $samples_dir, 'src', 'no_cov_cleaning' );
  make_path($dir);
  path( File::Spec->catfile( $dir, 'orphan.c' ) )->spew("int orphan(void) { return 0; }\n");
  test_warn_ok(
    sub { $cov->cleaning('src/no_cov_cleaning') },
    qr/WARNING: No coverage data matches path\(s\): src\/no_cov_cleaning/ms,
  );
  my $after = Local::Test::Helper::lcov2simple_hash( $cov->export );
  _unchanged_assert( $before, $after, 'cleaning по папке без покрытия не меняет покрытие' );
  remove_tree($dir);
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Пустой список files => [] ведёт себя как старый clip (warning, покрытие без изменений)
=cut
subtest 'Пустой список files => [] ведёт себя как старый clip (warning, покрытие без изменений)' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $before = Local::Test::Helper::lcov2simple_hash( $cov->export );
  test_warn_ok(
    sub { $cov->cleaning( files => [] ) },
    qr/WARNING: empty file list/ms,
  );
  my $after = Local::Test::Helper::lcov2simple_hash( $cov->export );
  _unchanged_assert( $before, $after, 'cleaning(files=>[]) не меняет покрытие' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Изменяет вызывающий экземпляр, ничего не возвращает
=cut
subtest 'Изменяет вызывающий экземпляр, ничего не возвращает' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $ret = $cov->cleaning('src/core_functions.c');
  ok( !defined $ret, 'cleaning ничего не возвращает' );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'root_one_file.lcov' ),
    'обнулен выбранный файл',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Один файл в корне
=cut
subtest 'Передаем на вход в files =>  один файл он лежит в корне' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->cleaning( $ROOT_SRC_ONE[0] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'root_one_file.lcov' ),
    'корневой файл',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в files =>  два файла, они лежат в корне
=cut
subtest 'Передаем на вход в files =>  два файла, они лежат в корне' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->cleaning( files => [ @ROOT_SRC_TWO ] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'root_two_files.lcov' ),
    'два файла в корне',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в files =>  много файлов, они лежат в корне
=cut
subtest 'Передаем на вход в files =>  много файлов, они лежат в корне' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->cleaning( files => [ @ROOT_SRC_MANY ] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'root_many_files.lcov' ),
    'много файлов в корне',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в files =>  один файл, он лежит в подпапке
=cut
subtest 'Передаем на вход в files =>  один файл, он лежит в подпапке' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->cleaning( $SUB_SRC_ONE[0] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'sub_one_file.lcov' ),
    'файл подпапки',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в files =>  два файла, они лежат в подпапке
=cut
subtest 'Передаем на вход в files =>  два файла, они лежат в подпапке' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->cleaning( files => [ @SUB_SRC_TWO ] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'sub_two_files.lcov' ),
    'два файла в подпапке',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в files =>  много файлов, они лежат в подпапке
=cut
subtest 'Передаем на вход в files =>  много файлов, они лежат в подпапке' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->cleaning( files => [ @SUB_SRC_MANY ] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'sub_many_files.lcov' ),
    'много файлов в подпапке',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в files =>  папка без под подпапок
=cut
subtest 'Передаем на вход в files =>  папка без под подпапок' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->cleaning('src/flat_two');
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'flat_two_dir.lcov' ),
    'папка без подпапок',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в files =>  папку с подпапками
=cut
subtest 'Передаем на вход в files =>  папку с подпапками' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->cleaning('src/backend');
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'backend_dir.lcov' ),
    'папка с подпапками',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в files =>  папку с подпапками, в подпапке лежит много файлов
=cut
subtest 'Передаем на вход в files =>  папку с подпапками, в подпапке лежит много файлов' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->cleaning('src/backend/utils');
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'backend_utils_dir.lcov' ),
    'папка с подпапками, много файлов',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: В files => [] передали произвольный файл, папку, подпапку
=cut
subtest 'В files => [] передали произвольный файл, папку, подпапку' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @input = qw( src/main.c src/flat_many src/backend/utils );
  $cov->cleaning( files => \@input );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'mixed_file_dir_subdir.lcov' ),
    'смешанный список',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Явные дубликаты дедуплицируются с warning
=cut
subtest 'В files => [] были переданы явные дубликаты, они не приводят к ошибке, дедуплицируются и выводит warning о дубликатах' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @input = qw( src/core_functions.c src/core_functions.c );
  my $cleaned;
  test_warn_ok(
    sub { $cleaned = $cov->cleaning( files => \@input ) },
    qr/WARNING: duplicate path/ms,
  );
  ok( !defined $cleaned, 'cleaning ничего не возвращает в warning-кейсе' );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'duplicate_explicit_paths.lcov' ),
    'явный дубликат',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: неявный дубликат - папка + файл внутри нее, в любом порядке
=cut
subtest 'неявный дубликат - папка + файл внутри нее, в любом порядке' => sub {
  my @orderings = (
    [ 'папка, затем файл', qw( src/backend/utils src/backend/utils/main_simple.c ) ],
    [ 'файл, затем папка', qw( src/backend/utils/main_simple.c src/backend/utils ) ],
  );
  my $expected = expected_lcov_path( $samples_dir, 'cleaning', 'duplicate_implicit_folder_file.lcov' );

  for my $ordering ( @orderings ) {
    my ( $label, @input ) = @$ordering;
    my $cov = build_cov_from_file( $src, $lcov );
    my $cleaned;
    test_warn_ok(
      sub { $cleaned = $cov->cleaning( files => \@input ) },
      qr/WARNING: redundant path/ms,
    );
    ok( !defined $cleaned, "$label: cleaning ничего не возвращает" );
    assert_lcov_eq(
      $cov->export,
      $expected,
      "$label: неявный дубликат",
    );
  }
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: В files => [] передали независимые подпапки
=cut
subtest 'В files => [] передали независимые подпапки' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @input = qw( src/flat_one src/flat_two );
  $cov->cleaning( files => \@input );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'independent_subdirs.lcov' ),
    'независимые подпапки',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: В files => [] передали вложенные подпапки вместе с папкой
=cut
subtest 'В files => [] передали вложенные подпапки вместе с папкой' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @input = qw( src/backend src/backend/utils );
  my $cleaned;
  test_warn_ok(
    sub { $cleaned = $cov->cleaning( files => \@input ) },
    qr/WARNING: redundant path/ms,
  );
  ok( !defined $cleaned, 'cleaning ничего не возвращает в warning-кейсе' );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'nested_backend_and_utils.lcov' ),
    'вложенные подпапки вместе с папкой',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: В files => [] передали список файлов
=cut
subtest 'В files => [] передали список файлов' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @in1 = qw( src/core_functions.c src/advanced_coverage.c );
  $cov->cleaning( files => \@in1 );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'list_two_files_root.lcov' ),
    'список файлов: корень',
  );

  my $cov2 = build_cov_from_file( $src, $lcov );
  my @in2 = qw( src/backend/utils/main_simple.c src/backend/utils/u_extra.c );
  $cov2->cleaning( files => \@in2 );
  assert_lcov_eq(
    $cov2->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'list_two_files_utils.lcov' ),
    'список файлов: подпапка',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Негативные
=head1 TEST: Некорректный элемент списка
=cut
subtest 'В files => [] некорректный элемент списка (undef / пустая строка / несуществующий путь) даёт ожидаемую ошибку' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  throws_ok { $cov->cleaning( files => [undef] ) } qr/ERROR: Each path must be a non-empty string/;
  throws_ok { $cov->cleaning( files => [''] ) } qr/ERROR: Each path must be a non-empty string/;
  throws_ok { $cov->cleaning( files => [ 'src/no_such_file.c' ] ) } qr/ERROR: Path 'src\/no_such_file\.c' does not exist/;
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Рекурсивная symlink-папка
=cut
subtest 'В files => [] были переданы рекурсивные папки, когда снизу ссылка ссылается на папку сверху.' => sub {
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
  $cov->cleaning( files => [ 'src/flat_one/mid/up' ] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'symlink_resolves_flat_one.lcov' ),
    'symlink цикл',
  );
  remove_tree($mid);
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Обнуляет из покрытия SF и содержимое для указанного файла; остальные исходники неизменны
=cut
subtest 'Обнуляет из покрытия SF и содержимое для указанного файла; остальные исходники неизменны' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $before = Local::Test::Helper::lcov2simple_hash( $cov->export );
  $cov->cleaning('src/core_functions.c');
  my $after = Local::Test::Helper::lcov2simple_hash( $cov->export );
  my $target = rel_to_abs_path( $samples_dir, 'src/core_functions.c' );
  my $zero = { map { $_ => 0 } keys %{ $before->{$target}->{DA} || {} } };
  is_deeply( $after->{$target}->{DA}, $zero, 'целевой SF обнулен' );
  delete $before->{$target};
  delete $after->{$target};
  _unchanged_assert( $before, $after, 'остальные SF неизменны' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Строка эквивалентна files=>[один элемент]
=cut
subtest 'Строка эквивалентна files=>[один элемент]' => sub {
  for my $path ( 'src/core_functions.c', 'src/backend/utils' ) {
    my $cov = build_cov_from_file( $src, $lcov );
    my $by_string = Local::Test::Helper::lcov2simple_hash(
      do { $cov->cleaning($path); $cov->export }
    );
    my $cov2 = build_cov_from_file( $src, $lcov );
    my $by_list = Local::Test::Helper::lcov2simple_hash(
      do { $cov2->cleaning( files => [$path] ); $cov2->export }
    );
    is_deeply( $by_string, $by_list, "$path: строка эквивалентна files=>[один элемент]" );
  }
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: cleaning обнуляет DA целевого файла
=cut
subtest 'cleaning обнуляет DA целевого файла' => sub {
  my $cov = build_cov_from_file( $src, "$samples_dir/simple.lcov" );
  my $before = Local::Test::Helper::lcov2simple_hash( $cov->export );
  $cov->cleaning('src/core_functions.c');
  my $after = Local::Test::Helper::lcov2simple_hash( $cov->export );
  my $target = rel_to_abs_path( $samples_dir, 'src/core_functions.c' );
  my $zero = { map { $_ => 0 } keys %{ $before->{$target}->{DA} || {} } };
  is_deeply( $after->{$target}->{DA}, $zero, 'DA целевого файла обнулены' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: cleaning принимает Code::CovTool::Sources в files
=cut
subtest 'cleaning принимает Code::CovTool::Sources в files' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->cleaning( files => [ $src ] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'zero_all_from_project_root_sources_arg.lcov' ),
    'files => [$src] обнуляет всё покрытие',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: cleaning поддерживает строковый корень (.)
=cut
subtest 'cleaning поддерживает строковый корень (.)' => sub {
  # Sources указывает на $samples_dir/src — на уровень глубже основного $src,
  # иначе '.' было бы эквивалентно cleaning(src/...) и не имело бы смысла.
  my $src_root = Code::CovTool::Sources->new( src_dir => File::Spec->catdir( $samples_dir, 'src' ) );
  my $cov_src_root = build_cov_from_file( $src_root, $lcov );
  $cov_src_root->cleaning('.');
  assert_lcov_eq(
    $cov_src_root->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'zero_all_from_src_subdir_dot.lcov' ),
    "строка '.' как корень обнуляет всё покрытие",
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: cleaning принимает Path::Tiny в files
=cut
subtest 'cleaning принимает Path::Tiny в files' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $pt = path('src/core_functions.c');
  $cov->cleaning( files => [ $pt ] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'cleaning', 'pathtiny_core_functions.lcov' ),
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
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Семантика путей: сопоставление по границе компонента (utils не задевает utils_helpers)
=cut
subtest 'Семантика путей: граница компонента (utils vs utils_helpers)' => sub {
  my $cov = build_cov_from_file( $src, $resolver_lcov );
  my $before = Local::Test::Helper::lcov2simple_hash( $cov->export );
  $cov->cleaning('src/resolver_test/utils');
  my $after = Local::Test::Helper::lcov2simple_hash( $cov->export );

  my $utils_abs   = rel_to_abs_path( $samples_dir, 'src/resolver_test/utils/u.c' );
  my $helpers_abs = rel_to_abs_path( $samples_dir, 'src/resolver_test/utils_helpers/h.c' );

  my $zero_utils = { map { $_ => 0 } keys %{ $before->{$utils_abs}->{DA} || {} } };
  is_deeply( $after->{$utils_abs}->{DA}, $zero_utils,
    'cleaning(utils): DA целевого файла обнулен' );

  is_deeply( $after->{$helpers_abs}, $before->{$helpers_abs},
    'cleaning(utils) не задевает utils_helpers/h.c' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
=head1 TYPE: Позитивные
=head1 TEST: Семантика путей: относительный путь эквивалентен абсолютному
=cut
subtest 'Семантика путей: rel ≡ abs' => sub {
  my $cov_rel = build_cov_from_file( $src, $resolver_lcov );
  $cov_rel->cleaning('src/resolver_test/utils/u.c');
  my $by_rel = Local::Test::Helper::lcov2simple_hash( $cov_rel->export );

  my $cov_abs = build_cov_from_file( $src, $resolver_lcov );
  my $abs_path = rel_to_abs_path( $samples_dir, 'src/resolver_test/utils/u.c' );
  $cov_abs->cleaning( $abs_path );
  my $by_abs = Local::Test::Helper::lcov2simple_hash( $cov_abs->export );

  is_deeply( $by_rel, $by_abs,
    'cleaning(rel) и cleaning(abs) дают одинаковый результат' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: cleaning
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

  my $cov_canon = build_cov_from_file( $src, $resolver_lcov );
  $cov_canon->cleaning( $forms[0] );
  my $canonical = Local::Test::Helper::lcov2simple_hash( $cov_canon->export );

  for my $form ( @forms[1..$#forms] ) {
    my $cov = build_cov_from_file( $src, $resolver_lcov );
    $cov->cleaning( $form );
    my $result = Local::Test::Helper::lcov2simple_hash( $cov->export );
    is_deeply( $result, $canonical, "форма '$form' эквивалентна канонической" );
  }
};

done_testing;
