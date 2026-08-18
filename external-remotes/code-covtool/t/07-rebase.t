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

use Local::Test::Helper;
use Code::CovTool;
use Code::CovTool::Sources;

use constant EXPECTED_COVERAGE => [2, 6, 27];

# setup func
sub add_comment {
  my ( $filename, $comment ) = @_;
  open my $fh, '>>', $filename or die "Can't open file $filename: $!";
  print $fh "$comment\n";
  close $fh;
};

sub replace_a_to_underscore {
  my $filename = shift;
  open my $fh, '<', $filename or die "Can't open file $filename: $!";
  my $content = do { local $/; <$fh> };
  close $fh;

  $content =~ s/a/_/g;

  open $fh, '>', $filename or die "Can't write in file $filename: $!";
  print $fh $content;
  close $fh;
};

sub prepare_samples_dir {
  return Local::Test::Helper::prepare_samples_dir(
    path_mapping => {
      '@PATH_TO_SOURCES@'            => '@TEMP_SAMPLES_DIR@',
      '@CREATE_NOT_COMPARABLE_FILE@' => '@TEMP_SRC_DIR@',
    },
  );
}

sub prepare_samples_with_subdirs {
  return Local::Test::Helper::prepare_samples_dir(
    path_mapping => {
      '@PATH_TO_SOURCES@'            => '@TEMP_SAMPLES_DIR@',
      '@CREATE_NOT_COMPARABLE_FILE@' => '@TEMP_SRC_DIR@',
    },
    nested_path  => [ 'test', 'nested_path' ]
  );
};

# setup nested
my $samples_nested_dir = prepare_samples_with_subdirs;

my $src_nested = Code::CovTool::Sources->new( src_dir => $samples_nested_dir );

my @expected_nested_before = (
  $src_nested->src_dir . '/test/nested_path/src/advanced_coverage.c',
  $src_nested->src_dir . '/test/nested_path/src/core_functions.c'
);

# setup
my $samples_dir = prepare_samples_dir;
my $other_dir   = prepare_samples_dir;

my $src        = Code::CovTool::Sources->new( src_dir => $samples_dir );
my $src_other  = Code::CovTool::Sources->new( src_dir => $other_dir );

my @expected_before = (
  $src->src_dir . '/src/advanced_coverage.c',
  $src->src_dir . '/src/core_functions.c'
);

my @expected_after = (
  $src_other->src_dir . '/src/advanced_coverage.c',
  $src_other->src_dir . '/src/core_functions.c'
);


=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Негативные
=head1 TEST: На вход может принимать только объект Code::CovTool::Sources
=cut
subtest 'На вход может принимать только объект Code::CovTool::Sources' => sub {
  my $r1 = Code::CovTool->new( src => $src, file => "$samples_dir/simple.lcov" );
  throws_ok(
    sub {
      $r1->rebase( bless {}, 'Test' )
    },
    qr/class does not match, should be Code::CovTool::Sources/
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Негативные
=head1 TEST: Файлы на которые ссылается lcov-файл [в корне исходников]. Удаляем исходный файл из source tree.
=cut
subtest 'Файлы на которые ссылается lcov-файл [в корне исходников]. Удаляем исходный файл из source tree.' => sub {
  my $other_dir = prepare_samples_dir;

  my $src_other = Code::CovTool::Sources->new( src_dir => $other_dir  );
  my $r1 = Code::CovTool->new( src => $src, file => "$samples_dir/simple.lcov" );

  unlink ( $src_other->src_dir . '/src/core_functions.c' );

  throws_ok(
    sub {
      $r1->rebase( $src_other );
    },
    qr{File 'src/core_functions\.c' from coverage not found in new source tree}
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Негативные
=head1 TEST: Файлы на которые ссылается lcov-файл [в корне исходников]. Файл изменяется, с изменением размера: добавляем комментарий.
=cut
subtest 'Файлы на которые ссылается lcov-файл [в корне исходников]. Файл изменяется, с изменением размера: добавляем комментарий.' => sub {
  my $other_dir = prepare_samples_dir;

  my $src_other = Code::CovTool::Sources->new( src_dir => $other_dir  );
  my $r1 = Code::CovTool->new( src => $src, file => "$samples_dir/simple.lcov" );

  add_comment( $src_other->src_dir . '/src/core_functions.c', '/*test*/' );

  throws_ok(
    sub {
      $r1->rebase( $src_other );
    },
    qr{File 'src/core_functions\.c' has different sizes between source trees. First: 365 bytes, Current: 374 bytes}
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Негативные
=head1 TEST: Файлы на которые ссылается lcov-файл [в корне исходников]. Файл изменяется, без изменения размера: заменяем все буквы 'a' на '_'.
=cut
subtest "Файлы на которые ссылается lcov-файл [в корне исходников]. Файл изменяется, без изменения размера: заменяем все буквы 'a' на '_'." => sub {
  my $other_dir = prepare_samples_dir;

  my $src_other = Code::CovTool::Sources->new( src_dir => $other_dir  );
  my $r1 = Code::CovTool->new( src => $src, file => "$samples_dir/simple.lcov" );

  replace_a_to_underscore( $src_other->src_dir . '/src/core_functions.c' );

  throws_ok(
    sub {
      $r1->rebase( $src_other );
    },
    qr{File 'src/core_functions\.c' has changed between source trees.}
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Негативные
=head1 TEST: Файлы на которые ссылается lcov-файл [вложенная структура каталогов]. Удаляем исходный файл из source tree.
=cut
subtest 'Файлы на которые ссылается lcov-файл [вложенная структура каталогов]. Удаляем исходный файл из source tree.' => sub {
  my $other_dir = prepare_samples_with_subdirs;

  my $src_other = Code::CovTool::Sources->new( src_dir => $other_dir  );
  my $r1  = Code::CovTool->new( src => $src_nested, file => "$samples_nested_dir/test/nested_path/simple.lcov" );

  unlink ( $src_other->src_dir . '/test/nested_path/src/core_functions.c' );

  throws_ok(
    sub {
      $r1->rebase( $src_other );
    },
    qr{File 'test/nested_path/src/core_functions\.c' from coverage not found in new source tree}
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Негативные
=head1 TEST: Файлы на которые ссылается lcov-файл [вложенная структура каталогов]. Файл изменяется, с изменением размера: добавляем комментарий.
=cut
subtest 'Файлы на которые ссылается lcov-файл [вложенная структура каталогов]. Файл изменяется, с изменением размера: добавляем комментарий.' => sub {
  my $other_dir = prepare_samples_with_subdirs;

  my $src_other = Code::CovTool::Sources->new( src_dir => $other_dir  );
  my $r1  = Code::CovTool->new( src => $src_nested, file => "$samples_nested_dir/test/nested_path/simple.lcov" );

  add_comment( $src_other->src_dir . '/test/nested_path/src/core_functions.c', '/*test*/' );

  throws_ok(
    sub {
      $r1->rebase( $src_other );
    },
    qr{File 'test/nested_path/src/core_functions\.c' has different sizes between source trees. First: 365 bytes, Current: 374 bytes}
  );
};

=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Негативные
=head1 TEST: Файлы на которые ссылается lcov-файл [вложенная структура каталогов]. Файл изменяется, без изменения размера: заменяем все буквы 'a' на '_'.
=cut
subtest "Файлы на которые ссылается lcov-файл [вложенная структура каталогов]. Файл изменяется, без изменения размера: заменяем все буквы 'a' на '_'." => sub {
  my $other_dir = prepare_samples_with_subdirs;

  my $src_other = Code::CovTool::Sources->new( src_dir => $other_dir  );
  my $r1  = Code::CovTool->new( src => $src_nested, file => "$samples_nested_dir/test/nested_path/simple.lcov" );

  replace_a_to_underscore( $src_other->src_dir . '/test/nested_path/src/core_functions.c' );

  throws_ok(
    sub {
      $r1->rebase( $src_other );
    },
    qr{File 'test/nested_path/src/core_functions\.c' has changed between source trees.}
  );
};


=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Позитивные
=head1 TEST: Файлы в source tree, не относящиеся к покрытию [в корне исходников]. Удаляем имеющийся файл.
=cut
subtest 'Файлы в source tree, не относящиеся к покрытию [в корне исходников]. Удаляем имеющийся файл.' => sub {
  my $other_dir = prepare_samples_dir;

  my $src_other = Code::CovTool::Sources->new( src_dir => $other_dir  );
  my $r1 = Code::CovTool->new( src => $src, file => "$samples_dir/simple.lcov" );

  my $new_file = File::Spec->catfile( "$other_dir/src", 'new_file.txt' );

  my $r1_export;
  my @files;

  ok( -e $new_file, "$new_file: файл существует после создания" );

  unlink ( $new_file );

  # до ребейза
  $r1_export = Local::Test::Helper::lcov2simple_hash( $r1->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $r1_export ) ], EXPECTED_COVERAGE );
  @files = sort keys %{$r1_export};

  is_deeply( \@files, \@expected_before );

  my $new_r = $r1->rebase( $src_other );
 
  # после ребейза
  ok( !-e $new_file, "$new_file: файл удален" );

  is $new_r->get_src_dir, $src_other->src_dir;
  my $new_r_export = Local::Test::Helper::lcov2simple_hash( $new_r->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $new_r_export ) ], EXPECTED_COVERAGE );

  @files = sort keys %{$new_r_export};

  my @expected_after = (
    $src_other->src_dir . '/src/advanced_coverage.c',
    $src_other->src_dir . '/src/core_functions.c'
  );

  is_deeply( \@files, \@expected_after );
};

=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Позитивные
=head1 TEST: Файлы в source tree, не относящиеся к покрытию [в корне исходников]. Файл изменяется, без изменения размера: заменяем все буквы 'a' на '_'.
=cut
subtest "Файлы в source tree, не относящиеся к покрытию [в корне исходников]. Файл изменяется, без изменения размера: заменяем все буквы 'a' на '_'." => sub {
  my $samples_dir = prepare_samples_dir;
  my $other_dir   = prepare_samples_dir;

  my $file_in_src_new_not_compare = File::Spec->catfile( "$other_dir/src", 'new_file.txt' );
  my $file_in_src_old_not_compare = File::Spec->catfile( "$samples_dir/src", 'new_file.txt' );

  my $src       = Code::CovTool::Sources->new( src_dir => $samples_dir );
  my $src_other = Code::CovTool::Sources->new( src_dir => $other_dir  );
  my $r1  = Code::CovTool->new( src => $src , file => "$samples_dir/simple.lcov" );

  my $r1_export;
  my @files;

  replace_a_to_underscore( $file_in_src_new_not_compare );

  # до ребейза
  $r1_export = Local::Test::Helper::lcov2simple_hash( $r1->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $r1_export ) ], EXPECTED_COVERAGE );

  @files = sort keys %{$r1_export};

  my @expected_before = (
    $src->src_dir . '/src/advanced_coverage.c',
    $src->src_dir . '/src/core_functions.c'
  );

  is_deeply( \@files, \@expected_before );

  my $check_not_compare = Local::Test::Helper::_check_files_not_to_compare( $src, $src_other, $r1->parsed_coverage_data );
  is $check_not_compare->{content_mismatch}, 'File is not unrelated to coverage: File \'src/new_file.txt\' has changed between source trees.';

  my $new_r = $r1->rebase( $src_other );

  # после ребейза
  is $new_r->get_src_dir, $src_other->src_dir;
  my $new_r_export = Local::Test::Helper::lcov2simple_hash( $new_r->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $new_r_export ) ], EXPECTED_COVERAGE );

  @files = sort keys %{$new_r_export};

  my @expected_after = (
    $src_other->src_dir . '/src/advanced_coverage.c',
    $src_other->src_dir . '/src/core_functions.c'
  );

  is_deeply( \@files, \@expected_after );
};

=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Позитивные
=head1 TEST: Файлы в source tree, не относящиеся к покрытию [в корне исходников]. Файл изменяется, с изменением размера: добавляем комментарий.
=cut
subtest 'Файлы в source tree, не относящиеся к покрытию [в корне исходников]. Файл изменяется, с изменением размера: добавляем комментарий.' => sub {
  my $samples_dir = prepare_samples_dir;
  my $other_dir   = prepare_samples_dir;

  my $file_in_src_new_not_compare = File::Spec->catfile( "$other_dir/src", 'new_file.txt' );
  my $file_in_src_old_not_compare = File::Spec->catfile( "$samples_dir/src", 'new_file.txt' );

  my $src       = Code::CovTool::Sources->new( src_dir => $samples_dir );
  my $src_other = Code::CovTool::Sources->new( src_dir => $other_dir  );
  my $r1  = Code::CovTool->new( src => $src , file => "$samples_dir/simple.lcov" );

  my $r1_export;
  my @files;

  add_comment( $file_in_src_new_not_compare, '/*test*/' );

  # до ребейза
  $r1_export = Local::Test::Helper::lcov2simple_hash( $r1->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $r1_export ) ], EXPECTED_COVERAGE );
  @files = sort keys %{$r1_export};
  my @expected_before = (
    $src->src_dir . '/src/advanced_coverage.c',
    $src->src_dir . '/src/core_functions.c'
  );
  is_deeply( \@files, \@expected_before );

  my $check_not_compare = Local::Test::Helper::_check_files_not_to_compare( $src, $src_other, $r1->parsed_coverage_data );
  is $check_not_compare->{invalid_size}, 'File is not unrelated to coverage: File \'src/new_file.txt\' has different sizes between source trees. First: 3 bytes, Current: 12 bytes';

  my $new_r = $r1->rebase( $src_other );

  # после ребейза
  is $new_r->get_src_dir, $src_other->src_dir;
  my $new_r_export = Local::Test::Helper::lcov2simple_hash( $new_r->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $new_r_export ) ], EXPECTED_COVERAGE );
  @files = sort keys %{$new_r_export};
  my @expected_after = (
    $src_other->src_dir . '/src/advanced_coverage.c',
    $src_other->src_dir . '/src/core_functions.c'
  );
  is_deeply( \@files, \@expected_after );
};


=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Позитивные
=head1 TEST: Файлы в source tree, не относящиеся к покрытию [вложенная структура каталогов]. Удаляем имеющийся файл.
=cut
subtest 'Файлы в source tree, не относящиеся к покрытию [вложенная структура каталогов]. Удаляем имеющийся файл.' => sub {
  my $other_dir = prepare_samples_with_subdirs;

  my $new_file = File::Spec->catfile( "$other_dir/test/nested_path/src", 'new_file.txt' );

  my $src_other = Code::CovTool::Sources->new( src_dir => $other_dir  );
  my $r1  = Code::CovTool->new( src => $src_nested , file => "$samples_nested_dir/test/nested_path/simple.lcov" );

  my $r1_export;
  my @files;

  ok( -e $new_file, "$new_file: файл существует после создания" );

  unlink ( $new_file );

  # до ребейза
  $r1_export = Local::Test::Helper::lcov2simple_hash( $r1->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $r1_export ) ], EXPECTED_COVERAGE );
  @files = sort keys %{$r1_export};

  is_deeply( \@files, \@expected_nested_before );

  my $new_r = $r1->rebase( $src_other );

  # после ребейза
  ok( !-e $new_file, "$new_file: файл удален" );

  is $new_r->get_src_dir, $src_other->src_dir;
  my $new_r_export = Local::Test::Helper::lcov2simple_hash( $new_r->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $new_r_export ) ], EXPECTED_COVERAGE );

  @files = sort keys %{$new_r_export};

  my @expected_nested_after = (
    $src_other->src_dir . '/test/nested_path/src/advanced_coverage.c',
    $src_other->src_dir . '/test/nested_path/src/core_functions.c'
  );

  is_deeply( \@files, \@expected_nested_after );
};

=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Позитивные
=head1 TEST: Файлы в source tree, не относящиеся к покрытию [вложенная структура каталогов]. Файл изменяется, без изменения размера: заменяем все буквы 'a' на '_'.
=cut
subtest "Файлы в source tree, не относящиеся к покрытию [вложенная структура каталогов]. Файл изменяется, без изменения размера: заменяем все буквы 'a' на '_'." => sub {
  my $samples_dir = prepare_samples_with_subdirs;
  my $other_dir   = prepare_samples_with_subdirs;

  my $file_in_src_new_not_compare = File::Spec->catfile( "$other_dir/test/nested_path/src", 'new_file.txt' );
  my $file_in_src_old_not_compare = File::Spec->catfile( "$samples_dir/test/nested_path/src", 'new_file.txt' );

  my $src       = Code::CovTool::Sources->new( src_dir => $samples_dir );
  my $src_other = Code::CovTool::Sources->new( src_dir => $other_dir  );
  my $r1  = Code::CovTool->new( src => $src , file => "$samples_dir/test/nested_path/simple.lcov" );

  my $r1_export;
  my @files;

  replace_a_to_underscore( $file_in_src_new_not_compare );

  # до ребейза
  $r1_export = Local::Test::Helper::lcov2simple_hash( $r1->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $r1_export ) ], EXPECTED_COVERAGE );

  @files = sort keys %{$r1_export};

  my @expected_nested_before = (
    $src->src_dir . '/test/nested_path/src/advanced_coverage.c',
    $src->src_dir . '/test/nested_path/src/core_functions.c'
  );

  is_deeply( \@files, \@expected_nested_before );

  my $check_not_compare = Local::Test::Helper::_check_files_not_to_compare( $src, $src_other, $r1->parsed_coverage_data );
  is $check_not_compare->{content_mismatch}, 'File is not unrelated to coverage: File \'test/nested_path/src/new_file.txt\' has changed between source trees.';

  my $new_r = $r1->rebase( $src_other );

  # после ребейза
  is $new_r->get_src_dir, $src_other->src_dir;
  my $new_r_export = Local::Test::Helper::lcov2simple_hash( $new_r->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $new_r_export ) ], EXPECTED_COVERAGE );

  @files = sort keys %{$new_r_export};

  my @expected_nested_after = (
    $src_other->src_dir . '/test/nested_path/src/advanced_coverage.c',
    $src_other->src_dir . '/test/nested_path/src/core_functions.c'
  );

  is_deeply( \@files, \@expected_nested_after );
};

=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Позитивные
=head1 TEST: Файлы в source tree, не относящиеся к покрытию [вложенная структура каталогов]. Файл изменяется, с изменением размера: добавляем комментарий.
=cut
subtest 'Файлы в source tree, не относящиеся к покрытию [вложенная структура каталогов]. Файл изменяется, с изменением размера: добавляем комментарий.' => sub {
  my $samples_dir = prepare_samples_with_subdirs;
  my $other_dir   = prepare_samples_with_subdirs;

  my $file_in_src_new_not_compare = File::Spec->catfile( "$other_dir/test/nested_path/src", 'new_file.txt' );
  my $file_in_src_old_not_compare = File::Spec->catfile( "$samples_dir/test/nested_path/src", 'new_file.txt' );

  my $src       = Code::CovTool::Sources->new( src_dir => $samples_dir );
  my $src_other = Code::CovTool::Sources->new( src_dir => $other_dir  );
  my $r1  = Code::CovTool->new( src => $src , file => "$samples_dir/test/nested_path/simple.lcov" );

  my $r1_export;
  my @files;

  add_comment( $file_in_src_new_not_compare, '/*test*/' );

  # до ребейза
  $r1_export = Local::Test::Helper::lcov2simple_hash( $r1->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $r1_export ) ], EXPECTED_COVERAGE );
  @files = sort keys %{$r1_export};
  my @expected_nested_before = (
    $src->src_dir . '/test/nested_path/src/advanced_coverage.c',
    $src->src_dir . '/test/nested_path/src/core_functions.c'
  );
  is_deeply( \@files, \@expected_nested_before );

  my $check_not_compare = Local::Test::Helper::_check_files_not_to_compare( $src, $src_other, $r1->parsed_coverage_data );
  is $check_not_compare->{invalid_size}, 'File is not unrelated to coverage: File \'test/nested_path/src/new_file.txt\' has different sizes between source trees. First: 3 bytes, Current: 12 bytes';

  my $new_r = $r1->rebase( $src_other );

  # после ребейза
  is $new_r->get_src_dir, $src_other->src_dir;
  my $new_r_export = Local::Test::Helper::lcov2simple_hash( $new_r->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $new_r_export ) ], EXPECTED_COVERAGE );
  @files = sort keys %{$new_r_export};
  my @expected_nested_after = (
    $src_other->src_dir . '/test/nested_path/src/advanced_coverage.c',
    $src_other->src_dir . '/test/nested_path/src/core_functions.c'
  );
  is_deeply( \@files, \@expected_nested_after );
};

=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Позитивные
=head1 TEST: После rebase пути SF в LCOV файле должны вести на валидные файлы в новом source tree
=cut
subtest 'После rebase пути SF в LCOV файле должны вести на валидные файлы в новом source tree' => sub {
  my $r1 = Code::CovTool->new( src => $src, file => "$samples_dir/simple.lcov" );

  my $r1_export;
  my @files;

  # до ребейза
  $r1_export = Local::Test::Helper::lcov2simple_hash( $r1->export );
  @files = sort keys %{$r1_export};
  is_deeply( \@files, \@expected_before );

  my $new_r = $r1->rebase( $src_other );

  # после ребейза
  my $new_r_export = Local::Test::Helper::lcov2simple_hash( $new_r->export );
  @files = sort keys %{$new_r_export};
  is_deeply( \@files, \@expected_after );
};

=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Позитивные
=head1 TEST: После ребейса, export должен возвращает файл идентичный исходному, отличаться должны только пути.
=cut
subtest 'После ребейса, export должен возвращает файл идентичный исходному, отличаться должны только пути.' => sub {
  my $r1 = Code::CovTool->new( src => $src, file => "$samples_dir/simple.lcov" );

  my $r1_export;
  my @files;

  # до ребейза
  $r1_export = Local::Test::Helper::lcov2simple_hash( $r1->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $r1_export ) ], EXPECTED_COVERAGE );
  @files = sort keys %{$r1_export};
  is_deeply( \@files, \@expected_before );

  my $new_r = $r1->rebase( $src_other );

  # после ребейза
  is $new_r->get_src_dir, $src_other->src_dir;
  my $new_r_export = Local::Test::Helper::lcov2simple_hash( $new_r->export );
  is_deeply( [ Local::Test::Helper::calculate_cov( $new_r_export ) ], EXPECTED_COVERAGE );
  @files = sort keys %{$new_r_export};
  is_deeply( \@files, \@expected_after );
};

=head1 GROUP: Методы
=head1 SUBGROUP: rebase
=head1 TYPE: Позитивные
=head1 TEST: Проверить правильность ребейса на пустом покрытии
=cut
subtest 'Проверить правильность ребейса на пустом покрытии' => sub {
  my $r1  = Code::CovTool->new( src => $src );

  is $r1->get_src_dir, $src->src_dir;
  
  my $new_r = $r1->rebase( $src_other );

  is $new_r->get_src_dir, $src_other->src_dir;
};

done_testing;
