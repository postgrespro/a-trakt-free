package Code::CovTool::Sources;

use strict;
use warnings;
use Moose;
use File::Spec;
use File::Find;
use File::Temp qw/ tempdir /;
use Cwd 'abs_path';
use Moose::Util::TypeConstraints;
use Scalar::Util qw( blessed );

=encoding utf8

=head1 NAME

Code::CovTool::Sources - работа с каталогом исходных файлов

=head1 SYNOPSIS

  use Path::Tiny qw( path );

  my $sources = Code::CovTool::Sources->new( src_dir => '/path/to/src' );
  my $sources2 = Code::CovTool::Sources->new( src_dir => path('/path/to/src') );
  $sources->check_path( $src_path, $line_num );
  my %files = $sources->get_file_list;
  my $rel_path = $sources->get_relative_path( $full_path );

=head1 DESCRIPTION

Представляет дерево исходников: проверяет существование и расположение файлов относительно
src_dir, возвращает списки файлов и относительные пути. Используется в Code::CovTool, Code::CovTool::PathResolver,
Code::CovTool::PathFilter, Code::CovTool::Tracefile и в тестовом Helper.

=head1 CONSTRUCTOR

=head2 new

  my $sources = Code::CovTool::Sources->new( src_dir => '/path/to/src' );

Создаёт экземпляр, привязанный к каталогу исходников.

=over 4

=item * B<src_dir> (обязательный)

Путь к существующей директории с исходным кодом (строка или C<Path::Tiny>).

=item * B<url> (опционально)

URL репозитория для L</get_sources>.

=back

=head1 METHODS

=head2 check_path

  $sources->check_path( $src_path, $line_num );

Проверяет путь из LCOV: файл должен существовать, быть обычным файлом и находиться внутри
src_dir. При ошибке завершает программу с сообщением (указывается номер строки в LCOV).

=over 4

=item * B<$src_path> — путь к исходнику (как в LCOV, может быть относительным или абсолютным)

=item * B<$line_num> — номер строки в LCOV (для сообщений об ошибках)

=back

Возвращает 1 при успехе.

=head2 get_file_list

  my %files = $sources->get_file_list;

Возвращает хэш: ключ — относительный путь от src_dir, значение — полный путь к файлу.
Включаются только файлы (директории не входят).

=head2 get_relative_path

  my $rel_path = $sources->get_relative_path( $full_path );

Преобразует полный путь в относительный к src_dir. Завершает программу, если путь
находится вне src_dir.

=over 4

=item * B<$full_path> — абсолютный путь к файлу

=back

Возвращает строку относительного пути.

=head2 get_sources

  $sources->get_sources;

Подтягивает исходники из git (если задан L</url>), если в src_dir ещё нет репозитория.
При ошибке клонирования завершает программу. Ничего не возвращает.

=head2 has_git_source

  my $has = $sources->has_git_source;

Проверяет, есть ли в src_dir директория .git (признак git-репозитория).

Возвращает истину или ложь.

=cut

has 'url' => (
  is       => 'ro',
  isa      => 'Str',
);

subtype 'ExistingDir',
  as 'Str',
  where {
    die 'Directory path cannot be empty' unless length($_);
    my $abs = abs_path($_);
    $abs && -d $abs or die "Directory $_ does not exist";
  };

coerce 'ExistingDir',
  from 'Object',
  via {
    die 'src_dir object must be Path::Tiny'
      unless blessed($_) && $_->isa('Path::Tiny');
    return "$_";
  };

has 'src_dir' => (
    is       => 'ro',
    isa      => 'ExistingDir',
    coerce   => 1,
    required => 1,
);

sub get_sources {
  my $self = shift;

  if ( $self->has_git_source ) {
    printf "Source files already found in folder: %s\n", $self->src_dir;
    return;
  }

  print "Get source files from git ...\n";

  system( sprintf 'cd %s && git clone %s', $self->src_dir, $self->url );

  die 'failed get sources from git' if $? == -1;

  return;
}

sub has_git_source {
    my $self = shift;

    my $found = 0;

    find(sub {
        if ( $_ eq '.git' && -d $_ ) {
            $found = 1;
            # Остановка поиска, если папка найдена
            $File::Find::prune = 1;
        }
    }, $self->src_dir);

    return $found;
}

sub check_path {
  my ( $self, $src_path, $line_num ) = @_;

  # Получаем абсолютный нормализованный путь
  my $abs_path = $self->_get_absolute_path( $src_path );

  # Проверка существования файла (с уточнением типа если это не файл)
  unless ( -e $abs_path ) {
    my $err = "[ln: $line_num] File does not exist: $abs_path (original path: $src_path)";
    $err .= '- this is a directory!' if -d $abs_path;
    die $err;
  }

  die "Path is not a regular file: $abs_path" unless -f _;

  # Проверка расположения в src_dir (с нормализацией сравнения путей)
  unless ( $self->_is_path_inside( $abs_path ) ) {
    die sprintf(
      "[ln: %d] File is outside source tree:\n" .
      "File: %s\nSource tree: %s",
      $line_num,
      $abs_path,
      $self->src_dir
    );
  }

  return 1;
}

sub _get_absolute_path {
  my ( $self, $path ) = @_;

  my $base_dir = $self->src_dir;

  # Если путь уже абсолютный
  if ( File::Spec->file_name_is_absolute( $path ) ) {
    return abs_path( $path ) || $path;
  }

  # Для относительных путей добавляем базовую директорию
  my $combined = File::Spec->catfile( $base_dir, $path );
  return abs_path( $combined ) || $combined;
}

sub _is_path_inside {
  my ( $self, $path ) = @_;

  my $dir = $self->src_dir;

  # Нормализуем пути
  $path = abs_path( $path ) || $path;
  $dir = abs_path( $dir ) || $dir;

  # Приводим пути к одинаковому формату
  $path = File::Spec->canonpath( $path );
  $dir = File::Spec->canonpath( $dir );

  # Проверяем что путь начинается с директории
  return index( $path, "$dir/" ) == 0;
}

sub get_file_list {
  my ( $self ) = @_;
  my %files;

  find(
    sub {
      return if -d $_;
      my $rel_path = File::Spec->abs2rel( $File::Find::name, $self->src_dir );
      $files{$rel_path} = $File::Find::name;
    }, $self->src_dir
  );

  return %files;
}

sub get_relative_path {
  my ( $self, $full_path ) = @_;

  # Нормализуем пути
  my $src_dir  = File::Spec->canonpath( File::Spec->rel2abs( $self->src_dir ) );
  my $abs_path = File::Spec->canonpath( File::Spec->rel2abs( $full_path ) );

  # Получаем относительный путь
  my $rel_path = File::Spec->abs2rel( $abs_path, $src_dir );

  # Проверяем, что путь находится внутри src_dir
  die "File '$full_path' is outside of source directory '$src_dir'"
    if $rel_path =~ /^\.\./;

  return $rel_path;
}

1;
