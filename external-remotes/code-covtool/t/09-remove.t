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
  test_warn_ok
  rel_to_abs_path
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

sub _assert_unchanged {
  my ( $before, $after, $msg ) = @_;
  is_deeply( $after, $before, $msg );
}

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Негативные
=head1 TEST: Вызов без аргументов
=cut
subtest 'Вызов без аргументов' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  throws_ok { $cov->remove() }
    qr/ERROR: Expected single path \(string\) or \( files => \\\@paths \)/;
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Подаем на вход корень исходников, должны получить покрытие с пустым списком учитываемых файлов.
=cut
subtest 'Подаем на вход корень исходников, должны получить покрытие с пустым списком учитываемых файлов.' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->remove('.');
  my $parsed = Local::Test::Helper::lcov2simple_hash( $cov->export );
  is( scalar keys %$parsed, 0, 'после remove(.) SF отсутствуют' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Негативные
=head1 TEST: Несуществующая директория
=cut
subtest 'Несуществующая директория' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  throws_ok { $cov->remove('src/no_such_dir') }
    qr/ERROR: Path 'src\/no_such_dir' does not exist/;
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: В { files => [] } Пустой список файлов, получаем объект с тем же покрытием и списком файлов
=cut
subtest 'В { files => [] } Пустой список файлов, получаем объект с тем же покрытием и списком файлов' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $before = Local::Test::Helper::lcov2simple_hash( $cov->export );
  my $ret = $cov->remove( files => [] );
  ok( !defined $ret, 'remove(files=>[]) ничего не возвращает' );
  my $after = Local::Test::Helper::lcov2simple_hash( $cov->export );
  _assert_unchanged( $before, $after, 'покрытие не изменилось' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход пустую папку (warning, покрытие без изменений)
=cut
subtest 'Передаем на вход пустую папку (warning, покрытие без изменений)' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $before = Local::Test::Helper::lcov2simple_hash( $cov->export );
  my $empty = File::Spec->catfile( $samples_dir, 'src', 'empty_remove' );
  make_path($empty);
  test_warn_ok(
    sub { $cov->remove('src/empty_remove') },
    qr/WARNING: No coverage data matches path\(s\): src\/empty_remove/ms,
  );
  my $after = Local::Test::Helper::lcov2simple_hash( $cov->export );
  _assert_unchanged( $before, $after, 'remove по пустой папке не меняет покрытие' );
  remove_tree($empty);
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Папка с файлами, которых нет в покрытии
=cut
subtest 'Папка с файлами, которых нет в покрытии' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $before = Local::Test::Helper::lcov2simple_hash( $cov->export );
  my $dir = File::Spec->catfile( $samples_dir, 'src', 'no_cov_remove' );
  make_path($dir);
  path( File::Spec->catfile( $dir, 'orphan.c' ) )->spew("int orphan(void) { return 0; }\n");
  test_warn_ok(
    sub { $cov->remove('src/no_cov_remove') },
    qr/WARNING: No coverage data matches path\(s\): src\/no_cov_remove/ms,
  );
  my $after = Local::Test::Helper::lcov2simple_hash( $cov->export );
  _assert_unchanged( $before, $after, 'remove по папке без покрытия не меняет покрытие' );
  remove_tree($dir);
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Изменяет вызывающий экземпляр, ничего не возвращает
=cut
subtest 'Изменяет вызывающий экземпляр, ничего не возвращает' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $before = Local::Test::Helper::lcov2simple_hash( $cov->export );
  my $ret = $cov->remove('src/core_functions.c');
  ok( !defined $ret, 'remove ничего не возвращает' );
  my $after = Local::Test::Helper::lcov2simple_hash( $cov->export );
  my $removed_abs = rel_to_abs_path( $samples_dir, 'src/core_functions.c' );
  delete $before->{$removed_abs};
  is_deeply( $after, $before, 'покрытие вызывающего экземпляра изменилось' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files => один файл, он лежит в корне }
=cut
subtest 'Передаем на вход в { files => один файл, он лежит в корне }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->remove( $ROOT_SRC_ONE[0] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'root_one_file.lcov' ),
    'один файл',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files => два файла, они лежат в корне }
=cut
subtest 'Передаем на вход в { files => два файла, они лежат в корне }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->remove( files => [ @ROOT_SRC_TWO ] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'root_two_files.lcov' ),
    'два файла в корне',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files => много файлов, они лежат в корне }
=cut
subtest 'Передаем на вход в { files => много файлов, они лежат в корне }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->remove( files => [ @ROOT_SRC_MANY ] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'root_many_files.lcov' ),
    'много файлов в корне',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files => один файл, он лежит в подпапке }
=cut
subtest 'Передаем на вход в { files => один файл, он лежит в подпапке }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->remove( $SUB_SRC_ONE[0] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'sub_one_file.lcov' ),
    'один файл в подпапке',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files => два файла, они лежат в подпапке }
=cut
subtest 'Передаем на вход в { files => два файла, они лежат в подпапке }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->remove( files => [ @SUB_SRC_TWO ] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'sub_two_files.lcov' ),
    'два файла в подпапке',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files => много файлов, они лежат в подпапке }
=cut
subtest 'Передаем на вход в { files => много файлов, они лежат в подпапке }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->remove( files => [ @SUB_SRC_MANY ] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'sub_many_files.lcov' ),
    'много файлов в подпапке',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files =>  папка без под подпапок }
=cut
subtest 'Передаем на вход в { files =>  папка без под подпапок }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->remove('src/flat_two');
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'flat_two_dir.lcov' ),
    'папка без подпапок',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files =>  папку с подпапками }
=cut
subtest 'Передаем на вход в { files =>  папку с подпапками }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->remove('src/backend');
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'backend_dir.lcov' ),
    'папка с подпапками',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Передаем на вход в { files =>  папку с подпапками, в подпапке лежит много файлов }
=cut
subtest 'Передаем на вход в { files =>  папку с подпапками, в подпапке лежит много файлов }' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->remove('src/backend/utils');
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'backend_utils_dir.lcov' ),
    'папка с подпапками, много файлов',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: В files => [] передали произвольный файл, папку, подпапку
=cut
subtest 'В { files => [] } передали произвольный файл, папку, подпапку' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @input = qw( src/main.c src/flat_many src/backend/utils );
  $cov->remove( files => \@input );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'mixed_file_dir_subdir.lcov' ),
    'произвольный файл, папка, подпапка',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Явные дубликаты дедуплицируются с warning
=cut
subtest 'Явные дубликаты дедуплицируются с warning' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @input = qw( src/core_functions.c src/core_functions.c );
  test_warn_ok(
    sub { $cov->remove( files => \@input ) },
    qr/WARNING: duplicate path/ms,
  );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'duplicate_explicit_paths.lcov' ),
    'явный дубликат',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: неявный дубликат - папка + файл внутри нее, в любом порядке
=cut
subtest 'неявный дубликат - папка + файл внутри нее, в любом порядке' => sub {
  my @orderings = (
    [ 'папка, затем подпапка', qw( src/backend src/backend/utils ) ],
    [ 'подпапка, затем папка', qw( src/backend/utils src/backend ) ],
  );
  my $expected = expected_lcov_path( $samples_dir, 'remove', 'nested_backend_and_utils_redundant.lcov' );

  for my $ordering ( @orderings ) {
    my ( $label, @input ) = @$ordering;
    my $cov = build_cov_from_file( $src, $lcov );
    test_warn_ok(
      sub { $cov->remove( files => \@input ) },
      qr/WARNING: redundant path/ms,
    );
    assert_lcov_eq(
      $cov->export,
      $expected,
      "$label: неявный дубликат",
    );
  }
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: В { files => [] } передали независимые подпапки
=cut
subtest 'В { files => [] } передали независимые подпапки' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @input = qw( src/flat_one src/flat_two );
  $cov->remove( files => \@input );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'independent_subdirs.lcov' ),
    'независимые подпапки',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: В { files => [] } передали вложенные подпапки вместе с папкой
=cut
subtest 'В { files => [] } передали вложенные подпапки вместе с папкой' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @input = qw( src/backend src/backend/utils );
  my $removed;
  test_warn_ok(
    sub {
      $cov->remove( files => \@input );
      $removed = 1;
    },
    qr/WARNING: redundant path/ms,
  );
  ok( $removed, 'remove завершился после warning' );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'nested_backend_and_utils_redundant.lcov' ),
    'вложенные подпапки дедуплицированы',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: В { files => [] } передали список файлов
=cut
subtest 'В { files => [] } передали список файлов' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my @in1 = qw( src/core_functions.c src/advanced_coverage.c );
  $cov->remove( files => \@in1 );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'list_two_files_root.lcov' ),
    'список файлов: корень',
  );

  my $cov2 = build_cov_from_file( $src, $lcov );
  my @in2 = qw( src/backend/utils/main_simple.c src/backend/utils/u_extra.c );
  $cov2->remove( files => \@in2 );
  assert_lcov_eq(
    $cov2->export,
    expected_lcov_path( $samples_dir, 'remove', 'list_two_files_utils.lcov' ),
    'список файлов: подпапка',
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Негативные
=head1 TEST: В { files => [] } некорректный элемент списка (undef / пустая строка / несуществующий путь) даёт ожидаемую ошибку
=cut
subtest 'В { files => [] } некорректный элемент списка (undef / пустая строка / несуществующий путь) даёт ожидаемую ошибку' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  throws_ok { $cov->remove( files => [undef] ) } qr/ERROR: Each path must be a non-empty string/;
  throws_ok { $cov->remove( files => [''] ) } qr/ERROR: Each path must be a non-empty string/;
  throws_ok { $cov->remove( files => [ 'src/no_such_file.c' ] ) } qr/ERROR: Path 'src\/no_such_file\.c' does not exist/;
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Рекурсивная symlink-папка
=cut
subtest 'Рекурсивная symlink-папка' => sub {
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
  $cov->remove( files => [ 'src/flat_one/mid/up' ] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'symlink_resolves_flat_one.lcov' ),
    'symlink цикл',
  );
  remove_tree($mid);
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Удаляет из покрытия SF и содержимое для указанного файла; остальные исходники неизменны
=cut
subtest 'Удаляет из покрытия SF и содержимое для указанного файла; остальные исходники неизменны' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $before = Local::Test::Helper::lcov2simple_hash( $cov->export );
  $cov->remove('src/core_functions.c');
  my $after = Local::Test::Helper::lcov2simple_hash( $cov->export );
  my $removed_abs = rel_to_abs_path( $samples_dir, 'src/core_functions.c' );
  ok( !exists $after->{$removed_abs}, 'целевой SF удален' );
  delete $before->{$removed_abs};
  _assert_unchanged( $before, $after, 'остальные SF неизменны' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Строка эквивалентна files=>[один элемент]
=cut
subtest 'Строка эквивалентна files=>[один элемент]' => sub {
  for my $path ( 'src/core_functions.c', 'src/backend/utils' ) {
    my $cov = build_cov_from_file( $src, $lcov );
    my $by_string = Local::Test::Helper::lcov2simple_hash(
      do { $cov->remove($path); $cov->export }
    );
    my $cov2 = build_cov_from_file( $src, $lcov );
    my $by_list = Local::Test::Helper::lcov2simple_hash(
      do { $cov2->remove( files => [$path] ); $cov2->export }
    );
    is_deeply( $by_string, $by_list, "$path: строка эквивалентна files=>[один элемент]" );
  }
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Развернуть и проверить, что все правильно удаляется для одного, двух и нескольких дублирующихся SF.
=cut
subtest 'Развернуть и проверить, что все правильно удаляется для одного, двух и нескольких дублирующихся SF.' => sub {
  my @cases = (
    [ 'остаются нетронутые файлы', 'core_removed_keeps_others', "$samples_dir/simple.lcov" ],
    [ 'покрытие очищается полностью', 'core_removed_to_empty', "$samples_dir/dublicate_sf_num.lcov" ],
  );

  for my $case ( @cases ) {
    my ( $label, $slug, @files ) = @$case;
    my $cov = build_cov_from_file( $src, shift @files );
    for my $file ( @files ) {
      my $next = build_cov_from_file( $src, $file );
      $cov->append( $next );
    }
    $cov->remove('src/core_functions.c');
    assert_lcov_eq(
      $cov->export,
      expected_lcov_path( $samples_dir, 'remove', "$slug.lcov" ),
      $label,
    );
  }
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: remove принимает Code::CovTool::Sources в files и поддерживает строковый корень (.)
=cut
subtest 'remove принимает Code::CovTool::Sources в files и поддерживает строковый корень (.)' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  $cov->remove( files => [ $src ] );
  my $parsed = Local::Test::Helper::lcov2simple_hash( $cov->export );
  is( scalar keys %$parsed, 0, 'files => [ $src ] удаляет весь корень' );

  my $src_root = Code::CovTool::Sources->new( src_dir => File::Spec->catdir( $samples_dir, 'src' ) );
  my $cov_src_root = build_cov_from_file( $src_root, $lcov );
  $cov_src_root->remove('.');
  my $parsed_alias = Local::Test::Helper::lcov2simple_hash( $cov_src_root->export );
  is( scalar keys %$parsed_alias, 0, 'строка "." распознана как корень при src_dir=.../src' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: remove принимает Path::Tiny в files
=cut
subtest 'remove принимает Path::Tiny в files' => sub {
  my $cov = build_cov_from_file( $src, $lcov );
  my $pt = path('src/core_functions.c');
  $cov->remove( files => [ $pt ] );
  assert_lcov_eq(
    $cov->export,
    expected_lcov_path( $samples_dir, 'remove', 'pathtiny_core_functions.lcov' ),
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
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Семантика путей: сопоставление по границе компонента (utils не задевает utils_helpers)
=cut
subtest 'Семантика путей: граница компонента (utils vs utils_helpers)' => sub {
  my $cov = build_cov_from_file( $src, $resolver_lcov );
  $cov->remove('src/resolver_test/utils');
  my @after = sort @{ $cov->get_file_list };
  my $expected = rel_to_abs_path( $samples_dir, 'src/resolver_test/utils_helpers/h.c' );
  is_deeply( \@after, [ $expected ],
    'remove(utils) не задевает utils_helpers — остался только h.c' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
=head1 TYPE: Позитивные
=head1 TEST: Семантика путей: относительный путь эквивалентен абсолютному
=cut
subtest 'Семантика путей: rel ≡ abs' => sub {
  my $cov_rel = build_cov_from_file( $src, $resolver_lcov );
  $cov_rel->remove('src/resolver_test/utils/u.c');
  my $by_rel = Local::Test::Helper::lcov2simple_hash( $cov_rel->export );

  my $cov_abs = build_cov_from_file( $src, $resolver_lcov );
  my $abs_path = rel_to_abs_path( $samples_dir, 'src/resolver_test/utils/u.c' );
  $cov_abs->remove( $abs_path );
  my $by_abs = Local::Test::Helper::lcov2simple_hash( $cov_abs->export );

  is_deeply( $by_rel, $by_abs,
    'remove(rel) и remove(abs) дают одинаковый результат' );
};

=head1 GROUP: Методы
=head1 SUBGROUP: remove
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

  # эталон — результат канонической формы
  my $cov_canon = build_cov_from_file( $src, $resolver_lcov );
  $cov_canon->remove( $forms[0] );
  my $canonical = Local::Test::Helper::lcov2simple_hash( $cov_canon->export );

  for my $form ( @forms[1..$#forms] ) {
    my $cov = build_cov_from_file( $src, $resolver_lcov );
    $cov->remove( $form );
    my $result = Local::Test::Helper::lcov2simple_hash( $cov->export );
    is_deeply( $result, $canonical, "форма '$form' эквивалентна канонической" );
  }
};

done_testing;
