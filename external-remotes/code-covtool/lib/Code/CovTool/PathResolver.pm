package Code::CovTool::PathResolver;

use strict;
use warnings;
use Moose;
use File::Spec;
use File::Compare;

=encoding utf8

=head1 NAME

Code::CovTool::PathResolver - перебазирование путей покрытия между деревьями исходников

=head1 SYNOPSIS

  my $resolver = Code::CovTool::PathResolver->new(
    old_sources => $old_cov_tool_sources,
    new_sources => $new_cov_tool_sources,
  );
  my $rebased_data = $resolver->rebase_coverage_data( $parsed_coverage );

=head1 DESCRIPTION

Проверяет совместимость двух деревьев исходников (одинаковые файлы по относительным путям),
сравнивает размеры и содержимое файлов, переводит данные покрытия с путей старого дерева
на пути нового дерева. Используется в Code::CovTool::rebase.

=cut

has 'old_sources' => (
  is       => 'ro',
  isa      => 'Code::CovTool::Sources',
  required => 1,
);

has 'new_sources' => (
  is       => 'ro', 
  isa      => 'Code::CovTool::Sources',
  required => 1,
);

has '_files_lookup' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_files_lookup',
);

sub rebase_coverage_data {
  my ( $self, $parsed_coverage ) = @_;

  $self->_check_source_compatibility( $parsed_coverage );
  return $self->_rebase_parsed_coverage( $parsed_coverage );
}

sub _check_source_compatibility {
  my ( $self, $parsed_coverage ) = @_;

  my @pairs_to_compare = $self->_find_files_to_compare( $parsed_coverage );
  return unless @pairs_to_compare;

  $self->_compare_file_pairs( \@pairs_to_compare );
}

sub _find_files_to_compare {
  my ( $self, $parsed_coverage ) = @_;

  my @covered_files = keys %$parsed_coverage;
  return unless @covered_files;

  my @pairs;
  
  # Получаем файлы из обоих source trees (относительные пути -> полные пути)
  my %old_files = $self->old_sources->get_file_list;
  my %new_files = $self->new_sources->get_file_list;

  foreach my $covered_full_path ( @covered_files ) {
    # Конвертируем полный путь из покрытия в относительный путь
    my $rel_path = $self->old_sources->get_relative_path( $covered_full_path );
    # Проверяем, что файл существует в обоих source trees
    if ( exists $old_files{$rel_path} && exists $new_files{$rel_path} ) {
      push @pairs, {
        rel_path => $rel_path,
        first    => $old_files{$rel_path},  # полный путь в старом tree
        current  => $new_files{$rel_path}   # полный путь в новом tree
      };
    } else {
      my $missing_in = exists $old_files{$rel_path} ? "new" : "old";
      die "File '$rel_path' from coverage not found in $missing_in source tree";
    }
  }

  return @pairs;
}

sub _compare_file_pairs {
  my ( $self, $pairs ) = @_;

  for my $pair ( @$pairs ) {
    my $rel_path     = $pair->{rel_path};
    my $first_file   = $pair->{first};
    my $current_file = $pair->{current};

    die "File '$rel_path' does not exist in first source tree: '$first_file'"
      unless -e $first_file;

    die "File '$rel_path' does not exist in current source tree: '$current_file'"
      unless -e $current_file;

    my $first_size = -s $first_file;
    my $current_size = -s $current_file;

    die
      "File '$rel_path' has different sizes between source trees. " .
      "First: $first_size bytes, Current: $current_size bytes"
      if ( $first_size != $current_size );

    # Сравниваем содержимое файлов
    die "File '$rel_path' has changed between source trees."
      if ( compare( $first_file, $current_file ) != 0 );
  }

  return;
}

sub _rebase_parsed_coverage {
  my ( $self, $parsed_coverage ) = @_;

  my %rebased_coverage;

  foreach my $old_filename ( keys %$parsed_coverage ) {
    my $new_filename = $self->_rebase_single_file_path( $old_filename );

    if ( $new_filename ) {
      $rebased_coverage{$new_filename} = $parsed_coverage->{$old_filename};
    } else {
      warn "WARNING: File '$old_filename' not found in new source tree, keeping original path\n";
      $rebased_coverage{$old_filename} = $parsed_coverage->{$old_filename};
    }
  }

  return \%rebased_coverage;
}

sub _build_files_lookup {
  my $self = shift;

  my %files = $self->new_sources->get_file_list;
  my %lookup = ( full => {}, base => {} );

  while ( my ( $rel_path, $new_full_path ) = each %files ) {
    # Полный путь в старом source tree для этого относительного пути
    my $old_full_path = File::Spec->catfile( $self->old_sources->src_dir, $rel_path );
    $lookup{full}{$old_full_path} = $new_full_path;

    my $basename = ( split('/', $rel_path) )[-1];
    if (!exists $lookup{base}{$basename}) {
      $lookup{base}{$basename} = $new_full_path;
    }
  }

  return \%lookup;
}

sub _rebase_single_file_path {
  my ( $self, $old_filename ) = @_;

  my $files_lookup = $self->_files_lookup;

  # Прямое отображение старый полный путь -> новый полный путь
  if ( exists $files_lookup->{full}{$old_filename} ) {
    return $files_lookup->{full}{$old_filename};
  }

  # Если не нашли по точному пути, пробуем найти по базовому имени
  my $basename = ( split('/', $old_filename) )[-1];
  if ( exists $files_lookup->{base}{$basename} ) {
    return $files_lookup->{base}{$basename};
  }

  return undef;
}

__PACKAGE__->meta->make_immutable;

1;
