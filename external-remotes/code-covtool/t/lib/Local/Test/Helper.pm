package Local::Test::Helper;

use strict;
use Exporter qw( import );
use File::Path qw( mkpath );
use File::Temp qw( tempdir );
use File::Compare;
use File::Copy;
use File::Basename;
use File::Spec;
use Test::More;
use Code::CovTool;

our @EXPORT_OK = qw(
  test_warn_ok
  prepare_samples_dir
  build_cov_from_file
  build_matrix_clip_case_cov
  read_file
  lcov2simple_hash
  rel_to_abs_path
  expected_lcov_path
  assert_lcov_eq
);

=head2 test_warn_ok

  test_warn_ok( sub { ... }, qr/.../ );

=head2 prepare_samples_dir

IN:
  Все параметры необязательные. По умолчанию используются данные из t/samples/coverage и t/samples/src.

  temp_dir     - Временная директория (по умолчанию создается автоматически)
  src_dir      - Директория с исходными кодами (по умолчанию копируется t/samples/src)
  samples_dir  - Директория с файлами покрытия (по умолчанию t/samples/coverage)
  nested_path  - Массив вложенных путей ['test', 'nested_path'] для создания иерархии
  path_mapping - Hashref для замены путей в файлах покрытия.
                 Ключи - макросы, значения - замены:
                    @PATH_TO_SOURCES@  - путь до исходников
                    @TEMP_SAMPLES_DIR@ - путь до временной директории (автоподстановка)

OUT:
  Путь к созданной временной директории

Description:
  Функция создает временную структуру каталогов, копирует исходные файлы из t/samples/src
  и дерево файлов из t/samples/coverage (рекурсивно, включая эталоны
  C<< <method>/expected/*.lcov >>), применяя заданные преобразования путей к каждому C<*.lcov>.

=cut

sub prepare_samples_dir {
  my ( %params ) = @_;

  my $temp_dir = $params{temp_dir} || tempdir( CLEANUP => 1 );
  my $samples_dir = $params{samples_dir} || File::Spec->catdir( $FindBin::Bin, 'samples/coverage');

  die "Directory $samples_dir not found" unless -d $samples_dir;

  my @nested_path = @{ $params{nested_path} || [] };

  my $target_coverage_dir = @nested_path 
    ? File::Spec->catdir( $temp_dir, @nested_path )
    : $temp_dir;

  if ( @nested_path && !-d $target_coverage_dir ) {
    mkpath( $target_coverage_dir ) or die "Cannot create directory $target_coverage_dir: $!";
  }

  # Копируем samples/src во вложенный путь если указан
  my $src_dir = $params{src_dir} || File::Spec->catdir( $FindBin::Bin, 'samples/src' );
  my $temp_src_dir;

  if ( @nested_path ) {
    $temp_src_dir = File::Spec->catdir( $target_coverage_dir, 'src' );
  } else {
    $temp_src_dir = File::Spec->catdir( $temp_dir, 'src' );
  }

  if ( !-d $temp_src_dir ) {
    mkpath( $temp_src_dir ) or die "Cannot create directory $temp_src_dir: $!";
  }

  copy_dir( $src_dir, $temp_src_dir ) if -d $src_dir;

  _copy_samples_coverage_tree(
    $samples_dir,
    $target_coverage_dir,
    $temp_dir,
    \@nested_path,
    $params{path_mapping},
    $temp_src_dir,
  );

  return $temp_dir;
}

# Рекурсивно копирует дерево samples/coverage (включая clip/expected и т.д.).
# Для файлов *.lcov построчно применяет path_mapping к префиксам SF:
sub _copy_samples_coverage_tree {
  my ( $src_root, $dst_root, $temp_dir, $nested_path_aref, $path_mapping, $temp_src_dir ) = @_;

  my @sf_rules;
  if ($path_mapping) {
    for my $pattern ( sort keys %$path_mapping ) {
      my $replacement = $path_mapping->{$pattern};
      if ( $pattern eq '@CREATE_NOT_COMPARABLE_FILE@' && $replacement eq '@TEMP_SRC_DIR@' ) {
        create_not_comparable_file( $temp_src_dir );
        next;
      }

      my $actual_replacement = $replacement eq '@TEMP_SAMPLES_DIR@'
        ? $temp_dir
        : $replacement;
      my $f_replacement = @$nested_path_aref
        ? File::Spec->catdir( $actual_replacement, @$nested_path_aref )
        : $actual_replacement;
      push @sf_rules, [ $pattern, $f_replacement ];
    }
  }

  my @stack = ( [ $src_root, $dst_root ] );

  while ( my $frame = pop @stack ) {
    my ( $src_dir, $dst_dir ) = @$frame;
    opendir( my $dh, $src_dir ) or die "Cannot open $src_dir: $!";

    while ( my $name = readdir( $dh ) ) {
      next if $name =~ /^\.\.?$/;

      my $src_path = File::Spec->catfile( $src_dir, $name );
      my $dst_path = File::Spec->catfile( $dst_dir, $name );

      if ( -d $src_path ) {
        mkpath( $dst_path ) unless -d $dst_path;
        push @stack, [ $src_path, $dst_path ];
        next;
      }

      next unless -f $src_path;

      my ( $base, $dir, $suffix ) = fileparse( $name, qr/\.[^.]*/ );
      if ( $suffix ) {
        $suffix = lc $suffix;
        $dst_path = File::Spec->catfile( $dst_dir, $base . $suffix );
      }

      if ( $suffix && $suffix eq '.lcov' ) {
        open( my $in_fh, '<', $src_path ) or die "Cannot open $src_path: $!";
        open( my $out_fh, '>', $dst_path ) or die "Cannot create $dst_path: $!";

        while ( my $line = <$in_fh> ) {
          my $modified_line = $line;
          if ( @sf_rules && index( $modified_line, 'SF:' ) == 0 ) {
            for my $rule (@sf_rules) {
              my ( $pattern, $f_replacement ) = @$rule;
              $modified_line =~ s/^SF:\Q$pattern\E/SF:$f_replacement/;
            }
          }
          print $out_fh $modified_line;
        }

        close $in_fh;
        close $out_fh;
      }
      else {
        copy( $src_path, $dst_path ) or die "Cannot copy $src_path -> $dst_path: $!";
      }
    }

    closedir $dh;
  }

  return;
}

sub create_not_comparable_file {
  my $dir = shift;

  my $new_file = File::Spec->catfile( "$dir", 'new_file.txt' );
  open( my $fh, '>', $new_file ) or die "Cannot open $new_file: $!";
  print $fh 'aaa';
  close $fh;

  return;
}

sub get_reference_coverage {
  my $dir = shift;

  die "Directory '$dir' does not exist" unless -d $dir;

  my %results;

  opendir( my $dh, $dir ) or die "Cannot open $dir: $!";

  while ( my $entry = readdir( $dh ) ) {
    next if $entry =~ /^\.\.?$/;
    next unless $entry =~ /\.lcov$/;

    my $filepath = File::Spec->catfile( $dir, $entry );

    next unless -f $filepath && -r $filepath;

    my $result = lcov2simple_hash( read_file( $filepath ) );

    $results{$entry} = $result;
  }

  closedir $dh;

  return %results;
}

sub copy_dir {
  my ( $src_dir, $dst_dir ) = @_;
  
  mkdir $dst_dir or die "Cannot create directory $dst_dir: $!" unless -d $dst_dir;

  opendir( my $dh, $src_dir ) or die "Cannot open $src_dir: $!";

  while ( my $item = readdir( $dh ) ) {
    next if $item =~ /^\.\.?$/;

    my $src_path = File::Spec->catfile( $src_dir, $item );
    my $dst_path   = File::Spec->catfile( $dst_dir, $item );

    if ( -d $src_path ) {
      # Рекурсивно копируем поддиректорию
      copy_dir( $src_path, $dst_path );
    } else {
      # Копируем файл
      copy( $src_path, $dst_path ) or die "Cannot copy from $src_path in $dst_path: $!";
    }
  }

  closedir $dh;
}

=head2 lcov2simple_hash

  my $parsed = Helper::lcov2simple_hash( $lcov_export );

Парсит строку LCOV и возвращает хэш:

- **Ключ верхнего уровня** — абсолютный путь к файлу (`SF:` в LCOV).
- **SF** — строка с тем же абсолютным путём.
- **DA** — хэш `номер_строки => hits`:

  DA:10,1  ⇒  `$parsed->{$file}->{DA}->{10} = '1'`

- **FN** — хэш `имя_функции => номер_строки_объявления`:

  FN:42,func  ⇒  `$parsed->{$file}->{FN}->{func} = '42'`

- **FNDA** — хэш `имя_функции => hits`:

  FNDA:5,func ⇒ `$parsed->{$file}->{FNDA}->{func} = '5'`

- **FNF, FNH, LF, LH** — скаляры (строки из LCOV):

  FNF:4 ⇒ `$parsed->{$file}->{FNF} = '4'`

=cut

sub lcov2simple_hash {
    my ( $str ) = @_;
    my $result = {};

    my $file;
    for my $line ( split /\n/, $str ) {
        next if $line =~ /^TN:/;

        if ( $line =~ /^SF:(.*)/ ) {
          $file = $1;
          $result->{$file} ||= {};
          $result->{$file}->{SF} = $file;
          next;
        }

        if ( $line eq 'end_of_record' ) {
          $file = undef;
          next;
        }

        next unless defined $file;

        my ( $key, $val ) = split /:/, $line, 2;

        if ( $key eq 'DA' ) {
          my ( $line_no, $hit ) = split /,/, $val, 3;
          $result->{$file}->{$key} ||= {};
          $result->{$file}->{$key}->{$line_no} = $hit;
        }
        elsif ( $key eq 'FNDA' ) {
          my ( $hit, $fn_name ) = split /,/, $val, 2;
          $result->{$file}->{$key} ||= {};
          $result->{$file}->{$key}->{$fn_name} = $hit;
        }
        elsif ( $key eq 'FNH' || $key eq 'FNF' || $key eq 'LH' || $key eq 'LF' ) {
          $result->{$file}->{$key} = $val;
        }
        elsif ( $key eq 'FN' ) {
          my ( $line_no, $fn_name ) = split /,/, $val, 2;
          $result->{$file}->{$key} ||= {};
          $result->{$file}->{$key}->{$fn_name} = $line_no;
        }
    }

    return $result;
}

sub calculate_cov {
  my ( $data ) = shift;
  my $sf_count = scalar keys %$data;
  my $fn_count = 0;
  my $da_count = 0;

  foreach my $file ( keys %$data ) {
    my $file_data = $data->{$file} || {};

    if ( $file_data->{FN} && ref $file_data->{FN} eq 'HASH' ) {
      $fn_count += scalar keys %{ $file_data->{FN} };
    }

    if ( $file_data->{DA} && ref $file_data->{DA} eq 'HASH' ) {
      $da_count += scalar keys %{ $file_data->{DA} };
    }
  }

  return ( $sf_count, $fn_count, $da_count );
}

sub read_file { open my $fh, '<', shift; local $/; <$fh> }

=head2 expected_lcov_path

  my $path = expected_lcov_path( $samples_dir, 'clip', 'root_one_file.lcov' );

Путь к эталонному LCOV в дереве C<< t/samples/coverage/<method>/expected/ >> после
L</prepare_samples_dir> (файл лежит рядом с C<clip_plan.lcov> в временной копии).

=cut

sub expected_lcov_path {
  my ( $samples_dir, $method, $filename ) = @_;
  return File::Spec->catfile( $samples_dir, $method, 'expected', $filename );
}

=head2 assert_lcov_eq

  assert_lcov_eq( $lcov_string, $expected_abs_path, $label );

Сравнивает результат C<< lcov2simple_hash >> для фактической строки LCOV и эталонного файла.

=cut

sub assert_lcov_eq {
  my ( $got_lcov, $expected_path, $label ) = @_;
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  my $exp_lcov = read_file($expected_path);
  is_deeply( lcov2simple_hash($got_lcov), lcov2simple_hash($exp_lcov), $label );
}

sub test_warn_ok {
  my ( $code, $re ) = @_;
  my @w;
  local $SIG{__WARN__} = sub { push @w, shift };
  $code->();
  my $txt = join '', @w;
  like( $txt, $re, 'warning' );
}

sub build_cov_from_file {
  my ( $src, $lcov ) = @_;
  return Code::CovTool->new( src => $src, file => $lcov );
}

=head2 build_matrix_clip_case_cov

  my ( $cov, $case_rel ) = build_matrix_clip_case_cov(
    $src, $lcov, $samples_root, $case_slug, \@root_templates, \@sub_templates
  );

Строит синтетический кейс для тестов C<clip>:

- создает директорию C<src/clip_matrix/<case_slug>> и подпапку C<sub>;
- копирует в них шаблонные исходники из C<\@root_templates> и C<\@sub_templates>;
- оставляет в покрытии только скопированные SF (с новыми путями).

Это позволяет проверять поведение по форме входного пути (папка/подпапка),
не создвая руками постоянные тестовые сэмплы в репозитории.

=cut

sub build_matrix_clip_case_cov {
  my ( $src, $lcov, $samples_root, $case_slug, $root_src_rels, $sub_src_rels ) = @_;
  $root_src_rels ||= [];
  $sub_src_rels  ||= [];

  my $cov = build_cov_from_file( $src, $lcov );
  my $orig = $cov->parsed_coverage_data;
  my $case_rel = "src/clip_matrix/$case_slug";
  my $case_abs = rel_to_abs_path( $samples_root, $case_rel );
  my $sub_rel = "$case_rel/sub";
  my $sub_abs = rel_to_abs_path( $samples_root, $sub_rel );
  mkpath($case_abs);
  mkpath($sub_abs);

  # 1) Физически собираем структуру кейса (корень + sub).
  my @dst_map = _matrix_copy_sources_to_case( $samples_root, $case_rel, $sub_rel, $root_src_rels, $sub_src_rels );
  # 2) Переносим покрытие только для скопированных SF.
  my %new_data = _matrix_build_coverage_map( $samples_root, $orig, \@dst_map );

  $cov->parsed_coverage_data( \%new_data );
  $cov->coverage_data_sets( [] );
  return ( $cov, $case_rel );
}

sub _matrix_copy_sources_to_case {
  my ( $samples_root, $case_rel, $sub_rel, $root_src_rels, $sub_src_rels ) = @_;
  my @dst_map;

  for my $src_rel ( @$root_src_rels ) {
    my ( undef, undef, $name ) = File::Spec->splitpath($src_rel);
    my $dst_rel = "$case_rel/$name";
    my $src_abs = rel_to_abs_path( $samples_root, $src_rel );
    my $dst_abs = rel_to_abs_path( $samples_root, $dst_rel );
    copy( $src_abs, $dst_abs ) or die "Cannot copy from $src_abs to $dst_abs: $!";
    push @dst_map, [ $src_rel, $dst_rel ];
  }

  for my $src_rel ( @$sub_src_rels ) {
    my ( undef, undef, $name ) = File::Spec->splitpath($src_rel);
    my $dst_rel = "$sub_rel/$name";
    my $src_abs = rel_to_abs_path( $samples_root, $src_rel );
    my $dst_abs = rel_to_abs_path( $samples_root, $dst_rel );
    copy( $src_abs, $dst_abs ) or die "Cannot copy from $src_abs to $dst_abs: $!";
    push @dst_map, [ $src_rel, $dst_rel ];
  }

  return @dst_map;
}

sub _matrix_build_coverage_map {
  my ( $samples_root, $orig, $dst_map ) = @_;
  my %new_data;
  for my $pair ( @$dst_map ) {
    my ( $src_rel, $dst_rel ) = @$pair;
    my $src_key = rel_to_abs_path( $samples_root, $src_rel );
    my $dst_key = rel_to_abs_path( $samples_root, $dst_rel );
    $new_data{$dst_key} = $orig->{$src_key};
  }
  return %new_data;
}

sub rel_to_abs_path {
  my ( $samples_dir, $rel ) = @_;
  return File::Spec->catfile( $samples_dir, split m{/}, $rel );
}

sub _check_files_not_to_compare {
  my ( $old_sources, $new_sources, $parsed_coverage ) = @_;

  my @covered_files = keys %$parsed_coverage;

  my @pairs;

  # Получаем файлы из обоих source trees (относительные пути -> полные пути)
  my %old_files = $old_sources->get_file_list;
  my %new_files = $new_sources->get_file_list;

  my %covered_rel_paths;
  foreach my $covered_full_path ( @covered_files ) {
    my $rel_path = $old_sources->get_relative_path( $covered_full_path );
    $covered_rel_paths{$rel_path} = 1;
  }

  foreach my $rel_path ( keys %new_files ) {
    # Пропускаем файлы, которые есть в покрытии
    next if exists $covered_rel_paths{$rel_path};
    # Так же пропускаем lcov файлы
    next if $rel_path =~ /\.lcov$/;

    # Проверяем, что файл существует в обоих source trees
    unless ( exists $old_files{$rel_path} ) {
      return { file_not_found => "File is not unrelated to coverage: '$rel_path' not found in old source tree" };
    }

    my $first_file = $old_files{$rel_path};
    my $current_file = $new_files{$rel_path};

    my $first_size = -s $first_file;
    my $current_size = -s $current_file;

    if ( $first_size != $current_size ) {
      return { invalid_size =>
        "File is not unrelated to coverage: ".
        "File '$rel_path' has different sizes between source trees. " .
        "First: $first_size bytes, Current: $current_size bytes"
      };
    }

    # Сравниваем содержимое файлов
    if ( compare( $first_file, $current_file ) != 0 ) {
      return {
        content_mismatch =>
        "File is not unrelated to coverage: ".
        "File '$rel_path' has changed between source trees."
      };
    }
  }

  return;
}

1;
