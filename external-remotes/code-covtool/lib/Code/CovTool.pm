=encoding utf8

=head1 NAME

Code::CovTool - модуль для работы с файлами покрытия

=head1 VERSION

version 0.0.7

=head1 SYNOPSIS

    use Code::CovTool;
    use Code::CovTool::Sources;
    use Path::Tiny qw( path );

    # Объект с исходными файлами
    my $src = Code::CovTool::Sources->new( src_dir => '/tmp/src' );
    my $src_pt = Code::CovTool::Sources->new( src_dir => path('/tmp/src') );

    # Объекты покрытия которые планируем суммировать
    my $f1  = Code::CovTool->new( src => $src, file => 'data.lcov' );
    my $f2  = Code::CovTool->new( src => $src, file => 'data2.lcov' );

    # Для суммирования необходимо создать пустой объект и добавить в него объекты покрытия
    my $total = Code::CovTool->new( src => $src );

    # Проверка, что покрытие пустое
    my $is_empty = $total->is_empty;

    $total->append( $f1 );
    $total->append( $f2 );

    # Отправляем результирующий lcov-файл на stdout
    print $total->export;

    # Альтернатива получения суммы
    my $merged = $f1->add( $f2 );
    my $merged2 = $f1 + $f2;

    # Получаем список функций в покрытии
    my $all_function_names = $f1->get_function_list();
    my $subtree_function_names = $f1->get_function_list( 'src/backend/regex' );
    my $function_names_from_file = $f1->get_function_list( 'src/backend/regex/regexec.c' );

    # Получаем по имени информацию про функцию
    my $info = $f1->get_function_info( 'getsubdfa' );
    print "Находится в файле $info->{getsubdfa}->[0]->{filename}\n";
    print "Начиная со строки $info->{getsubdfa}->[0]->{start_line}\n";

    # Получаем объект с покрытием в которое входят все строки f2 которых нет в f1.
    my $excess  = $f1->excess( $f2 );
    my $excess2 = $f1 < $f2;

    # Получаем корень исходников
    my $source_tree_dir = $f1->get_src_dir;

    # Получаем список файлов в покрытии
    my $files = $f1->get_file_list;

    # Получаем покрытие только для указанных файлов и папок: остальные исходники исключаются из списка файлов, учитываемых при построении покрытия.
    # Полученное покрытие сохраняется в новом экземпляре класса Code::CovTool.
    my $clipped = $f1->clip( { files => ['src/backend/regex/regexec.c', 'src/backend/utils'] } ); # Получаем покрытие для списка файлов и папок
    my $clipped_file_only = $f1->clip( 'src/backend/regex/regexec.c' ); # Получаем покрытие для конкретного файла
    my $clipped_path_only = $f1->clip( 'src/backend/utils' );   # Получаем покрытие для конкретной папки

    # Удаляем покрытие для указанных файлов и папок; при экспорте из отчета исчезают все SF-поля для удаленных исходников, а для остальных покрытие остается неизменным.
    # Метод remove изменяет покрытие в вызывающем экземпляре объекта.
    $f1->remove( { files => ['src/backend/regex/regexec.c','src/backend/utils/adt/numeric.c'] } );
    $f1->remove( 'src/backend/regex/regexec.c' ); # удаляем файл из покрытия
    $f1->remove( 'src/backend/utils' ); # удаляем из покрытия все файлы в указанной папке.

    # Обнуляем покрытие для указанных файлов и папок, для всех остальных исходников покрытие остается неизменным.
    # Метод remove изменяет покрытие в вызывающем экземпляре объекта.
    $f1->cleaning( files => ['src/backend/regex/regexec.c','src/backend/utils/adt/numeric.c'] );
    $f1->cleaning( 'src/backend/regex/regexec.c' ); # Обнуляем покрытие для конкретного файла
    $f1->cleaning( 'src/backend/utils' ); # Обнуляем покрытие для конкретной папки

    # Получаем копию существующего экземпляра класса Code::CovTool
    my $clone_obj = $f1->clone();

    # Получаем объект в котором покрытие ссылается на другой source tree и обновлены пути к исходным файлам.
    my $old_src = Code::CovTool::Sources->new( src_dir => '/tmp/old_src'  );
    my $old_cov = Code::CovTool->new( src => $old_src, file => 'data.lcov' );
    my $new_src = Code::CovTool::Sources->new( src_dir => '/tmp/new_src'  );
    my $new_cov = $old_cov->rebase( $new_src );

=head1 DESCRIPTION

Библиотека предоставляет различные методы для работы с покрытием.
Позволяет суммировать покрытия, находить превышение (покажет все строки из покрытия A которых нет в B).
Так же позволяет накладывать различные фильтры на покрытие.
Так же можно получать список функций в покрытии и информацию о функции (в каком файле она находится и с какой строки начинается).

Поддерживает только ver1 и не поддерживает BRDA (branch coverage).
Данная версия модуля работает только с покрытием кода на языке C.

=head1 INSTALLATION
  perl Build.PL
  ./Build
  ./Build installdeps
  ./Build test
  ./Build install

=head1 CONSTRUCTOR

=head2 new

  my $sources = Code::CovTool::Sources->new( src_dir => '/tmp/src' );
  my $cov = Code::CovTool->new( src => $sources ); # создает пустой объект покрытия
  $cov = Code::CovTool->new(
    src  => $sources,
    file => 'data.lcov'
  ); # создает объект с данными

Создает новый экземпляр класса Code::CovTool для работы с данными покрытия кода.

=over 4

=item * B<src> (требуется)

Объект Code::CovTool::Sources, содержащий информацию об исходных файлах.

=item * B<file> (опционально)

Путь к файлу lcov формата для парсинга.

=back

Вернет объект Code::CovTool

=cut

=head1 METHODS

=head3 add

  my $src = Code::CovTool::Sources->new( src_dir => '/tmp/src' );

  my $f1  = Code::CovTool->new( src => $src, file => 'data.lcov' );
  my $f2  = Code::CovTool->new( src => $src, file => 'data2.lcov' );

  my $merged = $f1->add( $f2 );
  my $merged2 = $f1 + $f2;

Суммирует два набора данных покрытия.
Возвращает новый объект Code::CovTool, содержащий объединенные данные.

Оператор перегружен: можно использовать C<$cov1 + $cov2>.

=over 4

=item * B<$f2> (требуется)

Объект Code::CovTool для суммирования

=back

Возвращает новый объект Code::CovTool

=cut

=head3 append

  my $src = Code::CovTool::Sources->new( src_dir => '/tmp/src' );

  my $f1  = Code::CovTool->new( src => $src, file => 'data.lcov' );
  my $f2  = Code::CovTool->new( src => $src, file => 'data2.lcov' );

  my $total = Code::CovTool->new( src => $src ); # создаем пустой объект покрытия

  $total->append( $f1 );
  $total->append( $f2 );

Добавляет данные покрытия из другого объекта к текущему.
Данные не суммируются немедленно, а сохраняются для последующей обработки.

=over 4

=item * B<$f1> (требуется)

Объект Code::CovTool, данные которого нужно добавить

=item * B<$f2> (опционально)

Объект Code::CovTool, данные которого нужно добавить

=back

Не возвращает значения

=cut

=head3 clip

  my $clipped = $f1->clip( { files => ['src/backend/regex/regexec.c', 'src/backend/utils'] } );
  my $clipped_file_only = $f1->clip( 'src/backend/regex/regexec.c' );
  my $clipped_path_only = $f1->clip( 'src/backend/utils' );

Получает покрытие для указанных файлов и папок; все остальные исходники удаляются из покрытия.
Полученное покрытие сохраняется в новом экземпляре класса Code::CovTool (исходный объект не изменяется).

Один аргумент-строка интерпретируется как C<files =E<gt> [ $path ]>.

Проверки: пути должны существовать в дереве исходников; дубликаты дедуплицируются с warning.
Если передан пустой C<files>, возвращается новый пустой объект покрытия.

=over 4

=item * Строка — один путь (файл или папка), трактуется как массив C<files> из одного элемента

=item * C<files =E<gt> \@paths> — массив путей (файлы и/или папки)

=item * C<< { files =E<gt> \@paths } >> — конфигурационный hashref (в C<clip/remove/cleaning> сейчас поддерживается только ключ C<files>)

=item * В списке C<files> также допускается C<Code::CovTool::Sources> (используется его C<src_dir> как путь к корню исходников)

=item * В списке C<files> также допускается C<Path::Tiny> (используется строковое представление пути)

=item * Корень исходников можно указывать строкой (например C<.> или абсолютный путь до C<src_dir>)

=back

Возвращает новый объект Code::CovTool.

=cut

=head3 clone

  my $clone_obj = $f1->clone();

Возвращает глубокую копию текущего экземпляра Code::CovTool. Аргументы не принимает.

=cut

=head3 excess

  my $src = Code::CovTool::Sources->new( src_dir => '/tmp/src' );

  my $f1  = Code::CovTool->new( src => $src, file => 'data.lcov' );
  my $f2  = Code::CovTool->new( src => $src, file => 'data2.lcov' );

  my $excess  = $f1->excess( $f2 );
  my $excess2 = $f1 < $f2;

Вычисляет разницу покрытия между двумя наборами данных.
Возвращает новый объект Code::CovTool, содержащий только те строки и функции,
которые покрыты во втором наборе, но не покрыты в первом.

Оператор перегружен: можно использовать C<$cov1 < $cov2>.

=over 4

=item * B<$f2> (требуется)

Объект Code::CovTool для сравнения

=back

Возвращает новый объект Code::CovTool

=cut

=head3 export

  my $src = Code::CovTool::Sources->new( src_dir => '/tmp/src' );

  my $f1  = Code::CovTool->new( src => $src, file => 'data.lcov' );
  my $f2  = Code::CovTool->new( src => $src, file => 'data2.lcov' );

  my $merged = $f1->add( $f2 );
  print $merged->export;

Генерирует данные в формате, пригодном для обработки утилитами типа genhtml.

Возвращает строку в формате lcov

=cut

=head3 get_file_list

  my $src = Code::CovTool::Sources->new( src_dir => '/tmp/src' );

  my $cov  = Code::CovTool->new( src => $src, file => 'data.lcov' );

  my $files = $cov->get_file_list;

Возвращает ссылку на массив путей к файлам присутствующих в данных покрытия.

=cut

=head3 get_function_info

  my $src = Code::CovTool::Sources->new( src_dir => '/tmp/src' );

  my $search_name = 'getsubdfa';
  my $cov  = Code::CovTool->new( src => $src, file => 'data.lcov' );
  my $info = $cov->get_function_info( $search_name );

  print "Находится в файле $info->{$search_name}->[0]->{filename}\n";
  print "Начиная со строки $info->{$search_name}->[0]->{start_line}\n";

Возвращает информацию о конкретной функции.

=over 4

=item * B<$search_name> (требуется)

Имя функции для поиска (может быть как деманглированным, так и манглированным)

=back

Возвращает хэш с информацией о функции:
ключ - имя функции,
значение - массив хэшей с полями filename и start_line

=cut

=head3 get_function_list

  my $src = Code::CovTool::Sources->new( src_dir => '/tmp/src' );

  my $cov  = Code::CovTool->new( src => $src, file => 'data.lcov' );

  my $all_function_names = $cov->get_function_list();

  my $path;
  $path = 'src/backend/regex';
  my $subtree_function_names = $cov->get_function_list( $path );
  $path = 'src/backend/regex/regexec.c';
  my $function_names_from_file = $cov->get_function_list( $path );

Возвращает список функций, присутствующих в данных покрытия.

=over 4

=item * B<$path> (опционально)

Путь к файлу или директории для фильтрации функций

=back

Возвращает ссылку на массив имен функций

=cut

=head3 get_src_dir

  my $src = Code::CovTool::Sources->new( src_dir => '/tmp/src' );

  my $cov  = Code::CovTool->new( src => $src, file => 'data.lcov' );

  my $source_tree_dir = $cov->get_src_dir;

Возвращает директорию исходных кодов, связанную с объектом.

Возвращает путь к директории исходных кодов

=cut

=head3 is_empty

  my $src = Code::CovTool::Sources->new( src_dir => '/tmp/src' );

  my $cov = Code::CovTool->new( src => $src );

  if ($cov->is_empty) {
    print "Нет данных покрытия\n";
  }

Проверяет, содержит ли объект какие-либо данные покрытия.

Возвращает истину, если данные отсутствуют, ложь в противном случае

=cut

=head3 rebase

  my $old_src = Code::CovTool::Sources->new( src_dir => '/tmp/old_src'  );
  my $new_src = Code::CovTool::Sources->new( src_dir => '/tmp/new_src'  );

  my $old_cov = Code::CovTool->new( src => $old_src, file => 'data.lcov' );

  my $new_cov = $old_cov->rebase( $new_src );

Изменяет базовую директорию исходных кодов в данных покрытия, сохраняя относительные пути.

=over 4

=item * B<$new_src> (требуется)

Объект Code::CovTool::Sources с новой директорией исходных кодов

=back

Возвращает новый объект Code::CovTool с перебазированными данными

=cut

=head3 remove

  $f1->remove( { files => ['src/backend/regex/regexec.c','src/backend/utils/adt/numeric.c'] }  );
  $f1->remove( 'src/backend/regex/regexec.c' );
  $f1->remove( 'src/backend/utils' );

Удаляет покрытие для указанных файлов и папок; для всех остальных исходников покрытие остаётся неизменным.
Метод изменяет покрытие в вызывающем экземпляре объекта (ничего не возвращает).

Аргументы те же, что у L</clip>: строка, C<files =E<gt> \@paths> или C<< { files =E<gt> \@paths } >>, с теми же проверками.

=сut

=head3 cleaning

  $f1->cleaning( files => ['src/backend/regex/regexec.c','src/backend/utils/adt/numeric.c'] );
  $f1->cleaning( 'src/backend/regex/regexec.c' );
  $f1->cleaning( 'src/backend/utils' );

Обнуляет покрытие для указанных файлов и папок; для всех остальных исходников покрытие остаётся неизменным.
Метод изменяет покрытие в вызывающем экземпляре объекта (ничего не возвращает).

Аргументы те же, что у L</clip>: строка, C<files =E<gt> \@paths> или C<< { files =E<gt> \@paths } >>, с теми же проверками.

=cut

package Code::CovTool;

use Moose;
use Path::Tiny;
use FindBin;
use Storable qw( dclone );
use lib $FindBin::Bin."/lib";

use Code::CovTool::PathResolver;
use Code::CovTool::PathFilter;
use Code::CovTool::Tracefile;
use Code::CovTool::CoverageData;

use overload
  '+' => \&add,
  '<' => \&excess,
  fallback => 1;

use constant FULLY_ENTERED => 500;
use constant PARTIALLY_ENTERED => 5000;

our $VERSION = '0.0.7';

has 'src' => (
  is       => 'ro',
  isa      => 'Code::CovTool::Sources',
  required => 1,
);

has 'file' => (
  is       => 'ro',
  isa      => 'Str',
);

has 'coverage_data_sets' => (
  is      => 'rw',
  isa     => 'ArrayRef',
  default => sub { [] },
  trigger => sub { $_[0]->_invalidate_caches },
);

has 'parsed_coverage_data' => (
  is      => 'rw',
  isa     => 'HashRef',
  trigger => sub { $_[0]->_invalidate_caches },
);

has '_summary_cache' => (
  is      => 'rw',
  isa     => 'Maybe[HashRef]',
  default => undef,
);

has '_function_info_cache' => (
  is      => 'rw',
  isa     => 'Maybe[HashRef]',
  default => undef,
);

sub BUILD {
  my ( $self ) = @_;

  if ( exists $self->{file} ) {
    my $trace = Code::CovTool::Tracefile->new(
      tracefile => $self->file,
      sources   => $self->src,
    );
    $trace->validate_format;
    $self->parsed_coverage_data( $trace->parse );
  }
}

sub _path_filter {
  my ( $self ) = @_;
  return Code::CovTool::PathFilter->new( sources => $self->src );
}

sub _normalize_selector {
  my ( $self, $opts, @args ) = @_;
  $opts ||= {};

  my $selector;
  if ( @args == 1 && ref $args[0] eq 'HASH' ) {
    $selector = { %{ $args[0] } };
  } elsif ( @args == 1 ) {
    my $arg = $args[0];
    die 'ERROR: Expected string (path) or ( files => \\@paths )'
      if ref $arg;
    $selector = { files => [ $arg ] };
  } elsif ( @args == 2 && $args[0] eq 'files' ) {
    $selector = { files => $args[1] };
  } else {
    die 'ERROR: Expected single path (string) or ( files => \\@paths )';
  }

  my @unsupported = grep { $_ ne 'files' } keys %$selector;
  if ( @unsupported ) {
    my $keys = join ', ', sort @unsupported;
    die "ERROR: Unsupported selector key(s) for this method: $keys. Supported: files\n";
  }
  die 'ERROR: Selector must contain key "files"' unless exists $selector->{files};

  my $path_infos = $self->_path_filter->normalize_and_validate_files(
    {
      allow_empty_files   => $opts->{allow_empty_files},
      warn_on_empty_files => $opts->{warn_on_empty_files},
    },
    files => $selector->{files},
  );

  return { files => $path_infos };
}

sub _coverage_keys_for_selector {
  my ( $self, $selector, $summary ) = @_;

  my %matched;

  if ( $selector->{files} && @{ $selector->{files} } ) {
    $matched{$_} = 1 for $self->_path_filter->coverage_keys_for_paths( $selector->{files}, $summary );
  }

  return keys %matched;
}

sub _sum {
  my ( $self ) = @_;

  # Переиспользуем агрегированные данные, пока наборы покрытия не менялись.
  if ( defined $self->_summary_cache ) {
    return $self->_summary_cache;
  }

  my $sets = scalar @{ $self->coverage_data_sets }
    ? [ $self->parsed_coverage_data, @{ $self->coverage_data_sets } ]
    : [ $self->parsed_coverage_data ];

  my $summary = Code::CovTool::CoverageData::merge_datasets( $sets );
  $self->_summary_cache( $summary );

  return $summary;
}

sub _invalidate_caches {
  my ( $self ) = @_;
  $self->_summary_cache( undef );
  $self->_function_info_cache( undef );
  return;
}

sub _clone_obj {
  my ( $self ) = @_;
  return $self->meta->clone_object( $self );
}

sub _create_clean_obj {
  my ( $self, %opts ) = @_;

  my $new = $self->_clone_obj;
  $new->{src} = $opts{src} if exists $opts{src};
  $new->parsed_coverage_data( $opts{parsed_coverage_data} // {} );
  $new->coverage_data_sets( [] );

  return $new;
}

sub _build_function_info_cache {
  my ( $self ) = @_;
  my $summary_data = $self->_sum;
  my %cache;

  foreach my $filename ( keys %{ $summary_data } ) {
    foreach my $fname ( sort keys %{ $summary_data->{$filename}->{func} } ) {
      my $start_line = $summary_data->{$filename}->{func}->{$fname};
      my $normalized_name = $fname;
      # у нас может быть file:function_name
      $normalized_name =~ s/^[^:]*:// if ( $normalized_name =~ /:/ );

      push @{ $cache{$normalized_name} }, {
        filename   => $filename,
        start_line => $start_line,
      };
    }
  }

  $self->_function_info_cache( \%cache );
  return \%cache;
}

sub excess {
  my ( $self, $other ) = @_;

  die 'class does not match, should be Code::CovTool' unless ref $other eq ref $self;

  my $excess = $self->_create_clean_obj;

  my $cov_data1 = $self->parsed_coverage_data;
  my $cov_data2 = $other->parsed_coverage_data;

  my %result;

  foreach my $filename ( keys %$cov_data2 ) {
    my $other_src_dir = $other->src->src_dir;
    my $curr_src_dir  = $self->get_src_dir;
    my $curr_filename = $filename;

    # For cross-rebase scenarios
    if ( $other_src_dir ne $curr_filename ) {
      $curr_filename = $filename =~ s|$other_src_dir|$curr_src_dir|gr;
    }

    next unless exists $cov_data1->{$curr_filename};

    my $file1 = $cov_data1->{$curr_filename};
    my $file2 = $cov_data2->{$filename};

    my %sumcount;
    my %checkdata;

    foreach my $line ( keys %{ $file2->{sum} } ) {
      my $count1 = $file1->{sum}{$line} // 0;
      my $count2 = $file2->{sum}{$line};

      # Include line if it's covered in file2 but not in file1
      if ($count2 > 0 && $count1 == 0) {
        $sumcount{$line} = $count2;
        $checkdata{$line} = $file2->{check}{$line} if exists $file2->{check}{$line};
      } else {
        $sumcount{$line} = 0;
      }
    }

    # Then add lines that are only in file1 (mark as uncovered)
    foreach my $line ( keys %{ $file1->{sum} } ) {
      next if exists $sumcount{$line};
      $sumcount{$line} = 0;
    }

    my %funcdata;
    my %sumfnccount;

    foreach my $func ( keys %{ $file2->{func} } ) {
      my $count1 = $file1->{sumfnc}{$func} // 0;
      my $count2 = $file2->{sumfnc}{$func} // 0;

      $funcdata{$func} = $file2->{func}{$func};

      # Include function if it's covered in file2 but not in file1
      if ($count2 > 0 && $count1 == 0) {
        $sumfnccount{$func} = FULLY_ENTERED;
      } else {
        if ( $count2 > 0 && $count2 >= $count1 ) {
          $sumfnccount{$func} = PARTIALLY_ENTERED;
        } else {
          $sumfnccount{$func} = 0;
        }
      }
    }

    # Add functions that are only in file1 (mark as uncovered)
    foreach my $func ( keys %{ $file1->{func} } ) {
      next if exists $funcdata{$func};
      $funcdata{$func} = $file1->{func}{$func};
      $sumfnccount{$func} = 0;
    }

    if ( keys %sumcount || keys %funcdata ) {
      $result{$filename} = {
        sum     => \%sumcount,
        func    => \%funcdata,
        check   => \%checkdata,
        sumfnc  => \%sumfnccount,
      };
    }
  }

  $excess->parsed_coverage_data(\%result);

  return $excess;
}

sub add {
  my ( $self, $other ) = @_;

  die 'class does not match, should be Code::CovTool' unless ref $other eq ref $self;

  my $new = $self->_create_clean_obj;

  $new->append( $self );
  $new->append( $other );

  return $new;
}

sub append {
  my ( $self, $lcov ) = @_;
  die 'class does not match, should be Code::CovTool' unless ref $lcov eq ref $self;
  push @{ $self->coverage_data_sets }, $lcov->parsed_coverage_data;
  $self->_invalidate_caches;
  return;
}

sub export {
  my $self = shift;

  return Code::CovTool::CoverageData::to_lcov( $self->_sum );
}

sub get_file_list { return [ keys %{ $_[0]->_sum } ]; }
sub get_src_dir { return $_[0]->src->src_dir };

sub get_function_list {
  my ( $self, $path ) = @_;

  die 'Directory path cannot be empty' if defined( $path ) && $path eq '';

  my $summary_data = $self->_sum;
  my @files;

  if ( !$path ) {
    @files = keys %{ $summary_data };
  } else {
    my $path_info = $self->_path_filter->validate_path( $path );
    @files = @{ $self->_path_filter->coverage_keys_matching_path_info( $path_info, $summary_data ) };
  }

  my %uniq_names;
  foreach my $filename ( @files ) {
    foreach my $fname ( keys %{ $summary_data->{$filename}->{func} } ) {
      $uniq_names{$fname} = 1 unless exists $uniq_names{$fname};
    }
  }

  return [ sort keys %uniq_names ];
}

sub get_function_info {
  my ( $self, $search_name ) = @_;

  my $is_mangled_search = $self->_is_mangled_symbol( $search_name );
  my $cache = $self->_function_info_cache // $self->_build_function_info_cache;
  my $matches = $cache->{$search_name} // [];

  die 'function not found in current coverage' unless @$matches;

  if ( $is_mangled_search ) {
    my %seen_file;
    my @per_file = grep { !$seen_file{ $_->{filename} }++ } @$matches;
    return { $search_name => \@per_file };
  }

  return { $search_name => $matches };
}

sub _is_mangled_symbol {
  my ( $self, $fname ) = @_;
  return 1 if $fname =~ /^_Z/ || $fname =~ /^\?/ || $fname =~ /[^a-zA-Z0-9_:]/;
  return 0;
}

sub is_empty {
  my $self = shift;
  return !( keys %{ $self->{parsed_coverage_data} } || @{ $self->{coverage_data_sets} } );
}


sub rebase {
  my ( $self, $other_sources ) = @_;

  die 'class does not match, should be Code::CovTool::Sources'
    unless ref $other_sources eq 'Code::CovTool::Sources';

  my $resolver = Code::CovTool::PathResolver->new(
    old_sources => $self->src,
    new_sources => $other_sources,
  );

  my $rebased_data = $resolver->rebase_coverage_data( $self->parsed_coverage_data );

  my $new = $self->_create_clean_obj(
    src                  => $other_sources,
    parsed_coverage_data => $rebased_data,
  );

  return $new;
}

sub clip {
  my ( $self, @args ) = @_;
  my $selector = $self->_normalize_selector( { allow_empty_files => 1 }, @args );
  my $path_infos = $selector->{files};
  unless ( @$path_infos ) {
    my $new = $self->_create_clean_obj;
    return $new;
  }
  my $summary = $self->_sum;
  my @keep_keys = $self->_coverage_keys_for_selector( $selector, $summary );
  unless ( @keep_keys ) {
    my $new = $self->_create_clean_obj;
    return $new;
  }
  my %new_data;
  for my $key ( @keep_keys ) {
    $new_data{$key} = dclone( $summary->{$key} );
  }

  my $new = $self->_create_clean_obj( parsed_coverage_data => \%new_data );

  return $new;
}

sub remove {
  my ( $self, @args ) = @_;
  my $selector = $self->_normalize_selector( { allow_empty_files => 1 }, @args );
  my $path_infos = $selector->{files};
  return unless @$path_infos;

  my $summary = $self->_sum;
  my @remove_keys = $self->_coverage_keys_for_selector( $selector, $summary );
  unless ( @remove_keys ) {
    my $paths = join ', ', map { $_->{input_path} } @$path_infos;
    warn "WARNING: No coverage data matches path(s): $paths\n";
    return;
  }
  my %remove = map { $_ => 1 } @remove_keys;

  for my $filename ( keys %remove ) {
    delete $self->parsed_coverage_data->{$filename} if $self->parsed_coverage_data;
    delete $_->{$filename} for @{ $self->coverage_data_sets };
  }

  $self->_invalidate_caches;

  return;
}

sub cleaning {
  my ( $self, @args ) = @_;
  my $selector = $self->_normalize_selector(
    { allow_empty_files => 1, warn_on_empty_files => 1 },
    @args
  );
  my $path_infos = $selector->{files};
  return unless @$path_infos;

  my $summary = $self->_sum;
  my @zero_keys = $self->_coverage_keys_for_selector( $selector, $summary );
  unless ( @zero_keys ) {
    my $paths = join ', ', map { $_->{input_path} } @$path_infos;
    warn "WARNING: No coverage data matches path(s): $paths\n";
    return;
  }
  my %zero = map { $_ => 1 } @zero_keys;

  for my $filename ( keys %zero ) {
    if ( $self->parsed_coverage_data && $self->parsed_coverage_data->{$filename} ) {
      Code::CovTool::CoverageData::zero_file_data( $self->parsed_coverage_data->{$filename} );
    }
    for my $dataset ( @{ $self->coverage_data_sets } ) {
      if ( $dataset->{$filename} ) {
        Code::CovTool::CoverageData::zero_file_data( $dataset->{$filename} );
      }
    }
  }

  $self->_invalidate_caches;

  return;
}

sub clone {
  my ( $self ) = @_;

  die 'ERROR: clone() does not take any arguments' if @_ > 1;

  return $self->_clone_obj;
}

1;
