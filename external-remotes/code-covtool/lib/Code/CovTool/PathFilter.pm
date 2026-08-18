package Code::CovTool::PathFilter;

use strict;
use warnings;
use Moose;
use Cwd qw( realpath );
use File::Spec;
use Scalar::Util qw( blessed );

=encoding utf8

=head1 NAME

Code::CovTool::PathFilter - валидация путей и фильтрация ключей покрытия по путям

=head1 SYNOPSIS

  my $filter = Code::CovTool::PathFilter->new( sources => $cov_tool_sources );
  my $path_info = $filter->validate_path( 'src/backend/utils' );
  my $path_infos = $filter->normalize_and_validate_files( files => [ 'src/a.c', 'src/' ] );
  my @keys = $filter->coverage_keys_for_paths( $path_infos, $summary_hash );

=head1 DESCRIPTION

Проверяет пути относительно дерева исходников (Code::CovTool::Sources),
нормализует аргументы clip/remove (строка или files => []),
возвращает список ключей покрытия, соответствующих заданным путям (файл/директория).

=head1 CONSTRUCTOR

=head2 new

  my $filter = Code::CovTool::PathFilter->new( sources => $cov_tool_sources );

Создаёт экземпляр, привязанный к дереву исходников.

=over 4

=item * B<sources> (обязательный)

Объект L<Code::CovTool::Sources>.

=back

=head1 METHODS

=head2 validate_path

  my $path_info = $filter->validate_path( 'src/backend/utils' );

Нормализует путь, проверяет, что он существует внутри дерева исходников.
При ошибке завершает программу.

=over 4

=item * B<$path> — путь к файлу или директории (относительный или абсолютный)

=back

Возвращает хэш: C<rel_path>, C<full_path>, C<is_same_as_src_dir>; для корня src_dir
только C<is_same_as_src_dir =E<gt> 1>.

=head2 normalize_and_validate_files

  my $path_infos = $filter->normalize_and_validate_files( files => [ 'src/a.c', 'src/' ] );
  my $path_infos = $filter->normalize_and_validate_files( 'src/single.c' );
  my $path_infos = $filter->normalize_and_validate_files( $sources_obj );
  my $path_infos = $filter->normalize_and_validate_files( { files => [ 'src/a.c' ] } );
  my $path_infos = $filter->normalize_and_validate_files(
    { allow_empty_files => 1, warn_on_empty_files => 1 },
    files => []
  );

Принимает один путь (строка), C<files =E<gt> \@paths> или hashref-конфигурацию с ключом C<files>.
Для каждого пути вызывает L</validate_path>.

В списке путей также допускается объект C<Code::CovTool::Sources>: в этом случае
используется его C<src_dir> (удобно для явного указания корня исходников).
Также допускается объект C<Path::Tiny> — он приводится к строковому пути.

Дополнительные ключи в hashref-конфигурации допускаются и пока игнорируются.
Это сделано для совместимости внешнего API (например, когда hashref формируется
общим кодом), но сам C<PathFilter> обрабатывает только фильтрацию по путям.

По умолчанию пустой C<files =E<gt> []> не допускается (ошибка). Если передана опция
C<allow_empty_files =E<gt> 1>, возвращается пустой список path_info; при
C<warn_on_empty_files =E<gt> 1> дополнительно выводится warning.

Явные дубликаты (один и тот же относительный
путь) и пути, избыточные относительно другого элемента списка (папка уже покрывает файл),
из входной последовательности в результат не попадают — предупреждение на каждый отброшенный
элемент. Переданный массив C<files> не изменяется.

Возвращает ссылку на массив хэшей (как у L</validate_path> плюс C<rel_path_normalized>
и C<input_path>) — без дубликатов по C<rel_path_normalized> и без избыточных вложенных путей.

=head2 coverage_keys_matching_path_info

  my $keys = $filter->coverage_keys_matching_path_info( $path_info, $summary );

По одному path_info и хэшу покрытия возвращает ключи файлов, подходящие под путь
(файл — точное совпадение/суффикс, директория — префикс). Если путь совпадает с
корнем исходников — все ключи.

=over 4

=item * B<$path_info> — хэш от L</validate_path>

=item * B<$summary> — хэш данных покрытия (ключи — пути к файлам)

=back

Возвращает ссылку на массив ключей (путей).

=head2 coverage_keys_for_paths

  my @keys = $filter->coverage_keys_for_paths( $path_infos, $summary );

Объединяет результаты L</coverage_keys_matching_path_info> по всем path_info
(объединение множеств ключей без дубликатов).

=over 4

=item * B<$path_infos> — ссылка на массив path_info (результат L</normalize_and_validate_files>)

=item * B<$summary> — хэш данных покрытия

=back

Возвращает список ключей (путей к файлам в покрытии).

=cut

has 'sources' => (
  is       => 'ro',
  isa      => 'Code::CovTool::Sources',
  required => 1,
);

sub validate_path {
  my ( $self, $path ) = @_;

  my $src_dir = File::Spec->canonpath(
    File::Spec->rel2abs( $self->sources->src_dir )
  );

  my $full_path = File::Spec->file_name_is_absolute( $path )
    ? File::Spec->canonpath( $path )
    : File::Spec->canonpath(
        File::Spec->catfile( $src_dir, $path )
      );
  $full_path = File::Spec->rel2abs( $full_path );
  if ( -e $full_path ) {
    my $resolved = realpath($full_path);
    $full_path = $resolved if defined $resolved && length $resolved;
  }

  my $is_same_as_src_dir = ( $full_path eq $src_dir );

  return { is_same_as_src_dir => 1 } if $is_same_as_src_dir;

  my $rel_path = File::Spec->abs2rel( $full_path, $src_dir );
  die "ERROR: Path '$path' is outside of source directory '$src_dir'"
    if ( $rel_path =~ /^\.\./ || File::Spec->file_name_is_absolute( $rel_path ) );

  die "ERROR: Path '$path' does not exist in source tree '$src_dir'" unless -e $full_path;

  $rel_path = '.' if $rel_path eq '';

  return {
    rel_path          => $rel_path,
    full_path         => $full_path,
    is_same_as_src_dir => 0,
  };
}

sub normalize_and_validate_files {
  my ( $self, @args ) = @_;
  my $opts = {};
  if ( @args && ref $args[0] eq 'HASH' && !exists $args[0]->{files} ) {
    $opts = shift @args;
  }

  my ( $paths, $from_files_param );
  if ( @args == 1 && ref $args[0] eq 'HASH' ) {
    my $cfg = $args[0];
    die 'ERROR: Parameter hash must contain key "files"'
      unless exists $cfg->{files};
    die 'ERROR: Parameter "files" must be an array reference'
      unless ref $cfg->{files} eq 'ARRAY';
    $paths = $cfg->{files};
    $from_files_param = 1;
  } elsif ( @args == 1 ) {
    my $arg = $args[0];
    die 'ERROR: Expected string (path) or ( files => \\@paths )'
      if ref $arg;
    $paths            = [$arg];
    $from_files_param = 0;
  } elsif ( @args == 2 && $args[0] eq 'files' ) {
    my $arg = $args[1];
    die 'ERROR: Parameter "files" must be an array reference'
      unless ref $arg eq 'ARRAY';
    $paths            = $arg;
    $from_files_param = 1;
  } else {
    die 'ERROR: Expected single path (string) or ( files => \\@paths )';
  }

  if ( @$paths == 0 ) {
    if ( $opts->{allow_empty_files} ) {
      warn "WARNING: empty file list\n" if $opts->{warn_on_empty_files};
      return [];
    }
    die 'ERROR: Empty file list';
  }

  my @path_infos;
  my %seen_rel;

  for my $path ( @$paths ) {
    if ( ref($path) && ref($path) eq 'Code::CovTool::Sources' ) {
      $path = $path->src_dir;
    } elsif ( ref($path) && blessed($path) && $path->isa('Path::Tiny') ) {
      $path = "$path";
    }
    die 'ERROR: Each path must be a non-empty string'
      if !defined($path) || ref($path) || $path eq '';

    my $info = $self->validate_path( $path );
    my $rel = $info->{is_same_as_src_dir} ? '.' : $info->{rel_path};

    # Явная дедупликация: повтор того же rel в возвращаемый список не попадает.
    if ( exists $seen_rel{$rel} ) {
      warn "WARNING: duplicate path in file list: $path\n";
      next;
    }
    $seen_rel{$rel} = 1;
    push @path_infos, { %$info, rel_path_normalized => $rel, input_path => $path };
  }

  return $self->_drop_paths_covered_by_parent( \@path_infos );
}

sub _rel_is_strict_prefix_dir {
  my ( $self, $parent_rel, $child_rel ) = @_;

  return 0 if $parent_rel eq $child_rel;
  return 1 if $parent_rel eq '.' && $child_rel ne '.';
  return $child_rel =~ m{^\Q$parent_rel\E/};
}

sub _path_covers {
  my ( $self, $parent_info, $child_info ) = @_;

  my $prel = $parent_info->{rel_path_normalized};
  my $crel = $child_info->{rel_path_normalized};
  return 0 if $prel eq $crel;
  return 1 if $parent_info->{is_same_as_src_dir};
  return 0 unless -d ( $parent_info->{full_path} // '' );
  return $self->_rel_is_strict_prefix_dir( $prel, $crel );
}

sub _drop_paths_covered_by_parent {
  my ( $self, $path_infos ) = @_;

  # Неявная дедупликация: путь, уже покрытый другим элементом списка, из результата убираем.
  my @sorted = sort {
    length( $a->{rel_path_normalized} ) <=> length( $b->{rel_path_normalized} )
      || $a->{rel_path_normalized} cmp $b->{rel_path_normalized}
  } @$path_infos;

  my @kept;
  for my $info (@sorted) {
    my $redundant;
    for my $k (@kept) {
      next if $k->{rel_path_normalized} eq $info->{rel_path_normalized};
      if ( $self->_path_covers( $k, $info ) ) {
        warn "WARNING: redundant path in file list (already covered by '"
          . $k->{input_path}
          . "'): "
          . $info->{input_path} . "\n";
        $redundant = 1;
        last;
      }
    }
    push @kept, $info unless $redundant;
  }

  return \@kept;
}

sub coverage_keys_matching_path_info {
  my ( $self, $path_info, $summary ) = @_;

  return [ keys %$summary ] if $path_info->{is_same_as_src_dir};

  my $rel = $path_info->{rel_path} // $path_info->{rel_path_normalized};
  return [] unless defined $rel;

  if ( -f ( $path_info->{full_path} // '' ) ) {
    return [ grep { $_ eq $rel || $_ =~ /\Q$rel\E$/ } keys %$summary ];
  }
  return [ grep { $_ eq $rel || $_ =~ /\Q$rel\E(\/.*)?$/ } keys %$summary ];
}

sub coverage_keys_for_paths {
  my ( $self, $path_infos, $summary ) = @_;
  return () unless @$path_infos;

  my @summary_keys = keys %$summary;
  return @summary_keys unless @summary_keys;

  for my $path_info ( @$path_infos ) {
    return @summary_keys if $path_info->{is_same_as_src_dir};
  }

  my %matched;
  PATH_INFO:
  for my $path_info ( @$path_infos ) {
    my $rel = $path_info->{rel_path} // $path_info->{rel_path_normalized};
    next PATH_INFO unless defined $rel;

    if ( -f ( $path_info->{full_path} // '' ) ) {
      my $file_re = qr/\Q$rel\E$/;
      for my $key ( @summary_keys ) {
        $matched{$key} = 1 if $key eq $rel || $key =~ $file_re;
      }
      next PATH_INFO;
    }

    my $dir_re = qr/\Q$rel\E(\/.*)?$/;
    for my $key ( @summary_keys ) {
      $matched{$key} = 1 if $key eq $rel || $key =~ $dir_re;
    }
  }

  return keys %matched;
}

__PACKAGE__->meta->make_immutable;

1;
