#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../t/lib";
use File::Path qw( make_path remove_tree );
use File::Spec;

use Code::CovTool::Sources;
use Local::Test::Helper qw(
  prepare_samples_dir
  build_cov_from_file
  build_matrix_clip_case_cov
  read_file
  lcov2simple_hash
);
use Getopt::Long qw( GetOptions );
use Path::Tiny qw( path );

my ( $WRITE, $CHECK );
GetOptions(
  'write' => \$WRITE,
  'check' => \$CHECK,
) or die "Usage: $0 --write | --check\n";
die "Usage: $0 --write | --check\n" unless $WRITE xor $CHECK;

my $project_root = File::Spec->catdir( $FindBin::Bin, '..' );
my $t_root       = File::Spec->catdir( $project_root, 't' );
my $repo_cov     = File::Spec->catdir( $t_root, 'samples', 'coverage' );
my $repo_src     = File::Spec->catdir( $t_root, 'samples', 'src' );

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

sub canon_export {
  my ( $export, $temp_root ) = @_;
  my $q = quotemeta($temp_root);
  my $ph = '@PATH_TO_SOURCES@';
  $export =~ s/^SF:$q/SF:$ph/mg;
  return $export;
}

# функция приводит распарсенный LCOV-хеш к стабильной строке, чтобы сравнение было семантическим, а не по порядку ключей;
sub freeze_hash {
  my ($h) = @_;
  my $t = ref $h;
  return "\x00" if !defined $h;
  return "S$h" if !$t;
  die "unexpected ref $t" if $t ne 'HASH';
  return 'H' . join '', map { freeze_hash($_) . freeze_hash( $h->{$_} ) } sort keys %$h;
}

sub expected_repo_path {
  my ( $method, $slug ) = @_;
  return File::Spec->catfile( $repo_cov, $method, 'expected', "$slug.lcov" );
}

sub write_or_check {
  my ( $method, $slug, $body ) = @_;
  my $path = expected_repo_path( $method, $slug );
  make_path( File::Spec->catdir( $repo_cov, $method, 'expected' ) );

  if ($WRITE) {
    open my $fh, '>', $path or die "write $path: $!";
    print $fh $body;
    close $fh;
    print "wrote $path\n";
    return;
  }

  my $disk = -f $path ? read_file($path) : '';
  die "parsed mismatch: $path (run with --write to refresh)\n"
    if freeze_hash( lcov2simple_hash($body) ) ne freeze_hash( lcov2simple_hash($disk) );
  print "ok $path\n";
}

sub run_case {
  my ( $method, $slug, $builder, $root ) = @_;
  write_or_check( $method, $slug, canon_export( $builder->(), $root ) );
}

sub run_warn_case {
  my ( $method, $slug, $builder, $root ) = @_;
  local $SIG{__WARN__} = sub { };
  run_case( $method, $slug, $builder, $root );
}

sub run_symlink_case {
  my ( $method, $slug, $root, $builder ) = @_;
  my $mid = File::Spec->catfile( $root, 'src', 'flat_one', 'mid' );
  make_path($mid);
  my $up = File::Spec->catfile( $mid, 'up' );
  unlink $up if -l $up || -e _;

  if ( eval { symlink( '..', $up ); 1 } ) {
    run_case( $method, $slug, $builder, $root );
  } else {
    print "skip $method/symlink (no symlink)\n";
  }
  remove_tree($mid) if -d $mid;
}

my $root = prepare_samples_dir(
  samples_dir  => $repo_cov,
  src_dir      => $repo_src,
  path_mapping => { '@PATH_TO_SOURCES@' => '@TEMP_SAMPLES_DIR@' },
);
my $src  = Code::CovTool::Sources->new( src_dir => $root );
my $lcov = File::Spec->catfile( $root, 'clip_plan.lcov' );

my @clip_cases = (
  [ 'root_one_file', sub { build_cov_from_file( $src, $lcov )->clip( $ROOT_SRC_ONE[0] )->export } ],
  [ 'root_two_files', sub { build_cov_from_file( $src, $lcov )->clip( files => [@ROOT_SRC_TWO] )->export } ],
  [ 'root_many_files', sub { build_cov_from_file( $src, $lcov )->clip( files => [@ROOT_SRC_MANY] )->export } ],
  [
    'root_one_plus_sub_many',
    sub {
      build_cov_from_file( $src, $lcov )->clip( files => [@ROOT_SRC_ONE_SUB_SRC_MANY] )->export;
    }
  ],
  [ 'sub_one_file', sub { build_cov_from_file( $src, $lcov )->clip( $SUB_SRC_ONE[0] )->export } ],
  [ 'sub_two_files', sub { build_cov_from_file( $src, $lcov )->clip( files => [@SUB_SRC_TWO] )->export } ],
  [ 'sub_many_files', sub { build_cov_from_file( $src, $lcov )->clip( files => [@SUB_SRC_MANY] )->export } ],
  [ 'flat_two_dir', sub { build_cov_from_file( $src, $lcov )->clip('src/flat_two')->export } ],
  [ 'backend_dir', sub { build_cov_from_file( $src, $lcov )->clip('src/backend')->export } ],
  [ 'backend_utils_dir', sub { build_cov_from_file( $src, $lcov )->clip('src/backend/utils')->export } ],
  [
    'independent_subdirs',
    sub {
      build_cov_from_file( $src, $lcov )->clip( files => [ qw( src/flat_one src/flat_two ) ] )->export;
    }
  ],
  [
    'list_two_files_root',
    sub {
      build_cov_from_file( $src, $lcov )->clip( files => [ qw( src/core_functions.c src/advanced_coverage.c ) ] )->export;
    }
  ],
  [
    'list_two_files_utils',
    sub {
      build_cov_from_file( $src, $lcov )->clip( files => [ qw( src/backend/utils/main_simple.c src/backend/utils/u_extra.c ) ] )->export;
    }
  ],
  [
    'mixed_file_dir_subdir',
    sub {
      build_cov_from_file( $src, $lcov )->clip( files => [ qw( src/main.c src/flat_many src/backend/utils ) ] )->export;
    }
  ],
  [
    'append_simple_core_only',
    sub {
      build_cov_from_file( $src, File::Spec->catfile( $root, 'simple.lcov' ) )->clip('src/core_functions.c')->export;
    }
  ],
  [
    'append_duplicate_sf_two_records',
    sub {
      build_cov_from_file( $src, File::Spec->catfile( $root, 'dublicate_sf_num.lcov' ) )->clip('src/core_functions.c')->export;
    }
  ],
  [
    'append_duplicate_sf_many_records',
    sub {
      my $f = File::Spec->catfile( $root, 'dublicate_sf_num.lcov' );
      my $cov = build_cov_from_file( $src, $f );
      $cov->append( build_cov_from_file( $src, $f ) );
      return $cov->clip('src/core_functions.c')->export;
    }
  ],
  [
    'pathtiny_core_functions',
    sub {
      my $pt = path('src/core_functions.c');
      return build_cov_from_file( $src, $lcov )->clip( files => [$pt] )->export;
    }
  ],
);
for my $c (@clip_cases) { run_case( 'clip', $c->[0], $c->[1], $root ); }
my @clip_matrix_cases = (
  [ 'matrix_sngl_fldr_one',        \@TEMPLATE_ONE,  [] ],
  [ 'matrix_sngl_fldr_two',        \@TEMPLATE_TWO,  [] ],
  [ 'matrix_sngl_fldr_many',       \@TEMPLATE_MANY, [] ],
  [ 'matrix_fldr_empty_sub_empty', [],              [] ],
  [ 'matrix_fldr_empty_sub_one',   [],              \@TEMPLATE_ONE ],
  [ 'matrix_fldr_empty_sub_two',   [],              \@TEMPLATE_TWO ],
  [ 'matrix_fldr_empty_sub_many',  [],              \@TEMPLATE_MANY ],
  [ 'matrix_fldr_one_sub_empty',   \@TEMPLATE_ONE,  [] ],
  [ 'matrix_fldr_two_sub_empty',   \@TEMPLATE_TWO,  [] ],
  [ 'matrix_fldr_many_sub_empty',  \@TEMPLATE_MANY, [] ],
  [ 'matrix_fldr_one_sub_many',    \@TEMPLATE_ONE,  \@TEMPLATE_MANY ],
);
for my $case ( @clip_matrix_cases ) {
  my ( $slug, $root_rels, $sub_rels ) = @$case;
  run_case(
    'clip',
    $slug,
    sub {
      my ( $case_cov, $case_dir_rel ) = build_matrix_clip_case_cov( $src, $lcov, $root, $slug, $root_rels, $sub_rels );
      return $case_cov->clip($case_dir_rel)->export;
    },
    $root
  );
}
run_warn_case(
  'clip',
  'duplicate_explicit_paths',
  sub {
    my @input = qw( src/core_functions.c src/core_functions.c );
    return build_cov_from_file( $src, $lcov )->clip( files => \@input )->export;
  },
  $root
);
run_warn_case(
  'clip',
  'duplicate_implicit_folder_file',
  sub {
    my @input = qw( src/backend/utils src/backend/utils/main_simple.c );
    return build_cov_from_file( $src, $lcov )->clip( files => \@input )->export;
  },
  $root
);
run_warn_case(
  'clip',
  'nested_backend_and_utils',
  sub {
    my @input = qw( src/backend src/backend/utils );
    return build_cov_from_file( $src, $lcov )->clip( files => \@input )->export;
  },
  $root
);
run_symlink_case(
  'clip',
  'symlink_resolves_flat_one',
  $root,
  sub { build_cov_from_file( $src, $lcov )->clip( files => ['src/flat_one/mid/up'] )->export }
);

my @cleaning_cases = (
  [
    'root_one_file',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning( $ROOT_SRC_ONE[0] );
      return $cov->export;
    }
  ],
  [
    'root_two_files',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning( files => [@ROOT_SRC_TWO] );
      return $cov->export;
    }
  ],
  [
    'root_many_files',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning( files => [@ROOT_SRC_MANY] );
      return $cov->export;
    }
  ],
  [
    'sub_one_file',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning( $SUB_SRC_ONE[0] );
      return $cov->export;
    }
  ],
  [
    'sub_two_files',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning( files => [@SUB_SRC_TWO] );
      return $cov->export;
    }
  ],
  [
    'sub_many_files',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning( files => [@SUB_SRC_MANY] );
      return $cov->export;
    }
  ],
  [
    'flat_two_dir',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning('src/flat_two');
      return $cov->export;
    }
  ],
  [
    'backend_dir',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning('src/backend');
      return $cov->export;
    }
  ],
  [
    'backend_utils_dir',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning('src/backend/utils');
      return $cov->export;
    }
  ],
  [
    'mixed_file_dir_subdir',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning( files => [ qw( src/main.c src/flat_many src/backend/utils ) ] );
      return $cov->export;
    }
  ],
  [
    'independent_subdirs',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning( files => [ qw( src/flat_one src/flat_two ) ] );
      return $cov->export;
    }
  ],
  [
    'list_two_files_root',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning( files => [ qw( src/core_functions.c src/advanced_coverage.c ) ] );
      return $cov->export;
    }
  ],
  [
    'list_two_files_utils',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning( files => [ qw( src/backend/utils/main_simple.c src/backend/utils/u_extra.c ) ] );
      return $cov->export;
    }
  ],
  [
    'pathtiny_core_functions',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      my $pt = path('src/core_functions.c');
      $cov->cleaning( files => [$pt] );
      return $cov->export;
    }
  ],
  [
    'zero_all_from_project_root_sources_arg',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->cleaning( files => [$src] );
      return $cov->export;
    }
  ],
  [
    'zero_all_from_src_subdir_dot',
    sub {
      my $src_root = Code::CovTool::Sources->new( src_dir => File::Spec->catdir( $root, 'src' ) );
      my $cov = build_cov_from_file( $src_root, $lcov );
      $cov->cleaning('.');
      return $cov->export;
    }
  ],
);
for my $c (@cleaning_cases) { run_case( 'cleaning', $c->[0], $c->[1], $root ); }
run_warn_case(
  'cleaning',
  'duplicate_explicit_paths',
  sub {
    my $cov = build_cov_from_file( $src, $lcov );
    my @input = qw( src/core_functions.c src/core_functions.c );
    $cov->cleaning( files => \@input );
    return $cov->export;
  },
  $root
);
run_warn_case(
  'cleaning',
  'duplicate_implicit_folder_file',
  sub {
    my $cov = build_cov_from_file( $src, $lcov );
    my @input = qw( src/backend/utils src/backend/utils/main_simple.c );
    $cov->cleaning( files => \@input );
    return $cov->export;
  },
  $root
);
run_warn_case(
  'cleaning',
  'nested_backend_and_utils',
  sub {
    my $cov = build_cov_from_file( $src, $lcov );
    my @input = qw( src/backend src/backend/utils );
    $cov->cleaning( files => \@input );
    return $cov->export;
  },
  $root
);
run_symlink_case(
  'cleaning',
  'symlink_resolves_flat_one',
  $root,
  sub {
    my $cov = build_cov_from_file( $src, $lcov );
    $cov->cleaning( files => ['src/flat_one/mid/up'] );
    return $cov->export;
  }
);

my @remove_cases = (
  [
    'root_one_file',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->remove( $ROOT_SRC_ONE[0] );
      return $cov->export;
    }
  ],
  [
    'root_two_files',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->remove( files => [@ROOT_SRC_TWO] );
      return $cov->export;
    }
  ],
  [
    'root_many_files',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->remove( files => [@ROOT_SRC_MANY] );
      return $cov->export;
    }
  ],
  [
    'sub_one_file',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->remove( $SUB_SRC_ONE[0] );
      return $cov->export;
    }
  ],
  [
    'sub_two_files',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->remove( files => [@SUB_SRC_TWO] );
      return $cov->export;
    }
  ],
  [
    'sub_many_files',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->remove( files => [@SUB_SRC_MANY] );
      return $cov->export;
    }
  ],
  [
    'flat_two_dir',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->remove('src/flat_two');
      return $cov->export;
    }
  ],
  [
    'backend_dir',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->remove('src/backend');
      return $cov->export;
    }
  ],
  [
    'backend_utils_dir',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->remove('src/backend/utils');
      return $cov->export;
    }
  ],
  [
    'mixed_file_dir_subdir',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->remove( files => [ qw( src/main.c src/flat_many src/backend/utils ) ] );
      return $cov->export;
    }
  ],
  [
    'independent_subdirs',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->remove( files => [ qw( src/flat_one src/flat_two ) ] );
      return $cov->export;
    }
  ],
  [
    'list_two_files_root',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->remove( files => [ qw( src/core_functions.c src/advanced_coverage.c ) ] );
      return $cov->export;
    }
  ],
  [
    'list_two_files_utils',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      $cov->remove( files => [ qw( src/backend/utils/main_simple.c src/backend/utils/u_extra.c ) ] );
      return $cov->export;
    }
  ],
  [
    'core_removed_keeps_others',
    sub {
      my $cov = build_cov_from_file( $src, File::Spec->catfile( $root, 'simple.lcov' ) );
      $cov->remove('src/core_functions.c');
      return $cov->export;
    }
  ],
  [
    'core_removed_to_empty',
    sub {
      my $cov = build_cov_from_file( $src, File::Spec->catfile( $root, 'dublicate_sf_num.lcov' ) );
      $cov->remove('src/core_functions.c');
      return $cov->export;
    }
  ],
  [
    'pathtiny_core_functions',
    sub {
      my $cov = build_cov_from_file( $src, $lcov );
      my $pt = path('src/core_functions.c');
      $cov->remove( files => [$pt] );
      return $cov->export;
    }
  ],
);
for my $c (@remove_cases) { run_case( 'remove', $c->[0], $c->[1], $root ); }
run_warn_case(
  'remove',
  'duplicate_explicit_paths',
  sub {
    my $cov = build_cov_from_file( $src, $lcov );
    my @input = qw( src/core_functions.c src/core_functions.c );
    $cov->remove( files => \@input );
    return $cov->export;
  },
  $root
);
run_warn_case(
  'remove',
  'nested_backend_and_utils_redundant',
  sub {
    my $cov = build_cov_from_file( $src, $lcov );
    my @input = qw( src/backend src/backend/utils );
    $cov->remove( files => \@input );
    return $cov->export;
  },
  $root
);
run_symlink_case(
  'remove',
  'symlink_resolves_flat_one',
  $root,
  sub {
    my $cov = build_cov_from_file( $src, $lcov );
    $cov->remove( files => ['src/flat_one/mid/up'] );
    return $cov->export;
  }
);

print "done.\n";
