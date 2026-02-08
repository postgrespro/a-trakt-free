package SDL::Ranges;

=head1 NAME

SDL::Ranges - модуль для парсинга диапазонов версий.

=head1 SYNOPSIS

# Получаем объект в котором перечислены префиксы
my $rc = SDL::Ranges->new( prefixes => [ '', 'projA-', 'projB-' ] );

my $im;

# Точечный диапазон
$im = $rc->match( '1', '1' );
$im = $rc->match( 'projA-1', 'projA-1' );

# Закрытый диапазон
$im = $rc->match( '1-3', 2 );
$im = $rc->match( 'projA-(1-3)', 'projA-2' );
$im = $rc->match( 'projB-(10-15)', 'projB-13' );

# Открытый диапазон
$im = $rc->match( '30+', 31 );
$im = $rc->match( 'projA-12+', 'projA-13' );
$im = $rc->match( 'projB-12+', 'projB-13' );

# Комбинированные варианты
$im = $rc->match( '1,2,3', 2 );
$im = $rc->match( '1,10-20,30+', 11 );
$im = $rc->match( 'projA-1,projA-2,projA-3,projA-13', 'projA-2' );
$im = $rc->match( 'projA-1,projA-(10-20),projA-30+', 'projA-11' );
$im = $rc->match( '7,15-19,projA-11,projB-(14-15),projB-19+', 'projB-20' );
$im = $rc->match( '1,10-20,30+,13,17,projB-14,projB-15+', 'projB-16' );

# Два возможных варианта, match вернет true если подходит хотя бы один из них.
$im = $rc->match( '13,17,projA-(13-19),projB-14', 'projA-17', 17 );

$im = SDL::Ranges->new(); # Эквивалентно SDL::Ranges->new( prefixes => [''] )
$im->match( 'projA-(16-18)', 17 ); # Вызовет ошибку

# Так же есть метод validate который может проверить диапазон
my $is_invalid_range = $rc->validate( 'invalid_range_string' );
my $is_valid = $rc->validate( '1,projA-15+,projB-(10-15)' );

=head1 DESCRIPTION

Библиотека обеспечивает гибкое и точное управление версиями продукта.
Поддерживает описание диапазонов версий с помощью текстовых строк, которые могут включать точечные,
закрытые и открытые диапазоны.
В диапазонах могут использоваться префиксы для более точного указания версий.
Также реализованы методы для проверки, входит ли конкретная версия в заданный диапазон,
а также для валидации формата строки с диапазоном.

=cut

use Moose;
use Scalar::Util qw( looks_like_number );

has 'prefixes' => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    default => sub { [''] },
);

sub _has_only_default_prefix {
  my $self = shift;

  return @{ $self->prefixes } == 1 && $self->prefixes->[0] eq '';
};

sub _has_default_prefix {
  my $self = shift;

  return ( grep { $_ eq '' } @{ $self->prefixes } ) ? 1 : 0;
};

sub _parse_range {
  my ( $self, $range, $in_validate ) = @_;

  $in_validate ||= 0;

  # Числовые форматы
  if ( $self->_has_default_prefix ) {
    # Точечный диапазон
    return {
      format => 'digit',
      type   => 'exact',
      value  => $1,
    } if $range =~ /^(\d+)$/;
    # Закрытый диапазон
    return {
      format => 'digit',
      type   => 'range',
      from   => $1,
      to     => $2,
    } if $range =~ /^(\d+)-(\d+)$/;
    # Открытый диапазон
    return {
      format => 'digit',
      type   => 'open',
      from   => $1,
    } if $range =~ /^(\d+)\+$/;
  }

  # Префиксные форматы
  # Сначала проверяем точное соответствие зарегистрированным префиксам
  unless ( $self->_has_only_default_prefix ) {
    foreach my $prefix ( @{ $self->prefixes } ) {
      next if $prefix eq '';

      # Точное значение projA-12
      if ( $range =~ /^\Q$prefix\E(\d+)$/ ) {
        return {
          format => 'mix',
          type   => 'exact',
          prefix => $prefix,
          value  => $1,
        };
      }
      # Диапазон projA-(1-3)
      elsif ( $range =~ /^\Q$prefix\E\((\d+)-(\d+)\)$/ ) {
        return {
          format => 'mix',
          type   => 'range',
          prefix => $prefix,
          from   => $1,
          to     => $2,
        };
      }
      # Открытый диапазон projA-12+
      elsif ( $range =~ /^\Q$prefix\E(\d+)\+$/ ) {
        return {
          format => 'mix',
          type   => 'open',
          prefix => $prefix,
          from   => $1,
        };
      }
    }
  }

  # Если дошли сюда, значит формат не распознан
  return 0 if $in_validate;
  die "Invalid range format: '$range'. Valid formats:\n" .
      "For numbers: 17, 16-18, 30+\n" .
      "With prefixes: 'prefix15', 'prefix(10-20)', 'prefix10+'\n" .
      "Configured prefixes: [" .
      join(
        ', ', map { "'$_'" } @{ $self->prefixes }
      ) . "]";
}

sub _match {
  my ( $self, $range, $entry ) = @_;

  my $parsed = $self->_parse_range( $range );

  my ( $entry_prefix, $entry_suffix ) = $entry =~ /^(\D+)(\d+)$/;

  die "prefix '$entry_prefix' not found in prefixes."
    if $entry_suffix && $self->_has_only_default_prefix;

  if (
    $parsed->{format} eq 'digit'
    && looks_like_number( $entry )
  ) {
    return $entry == $parsed->{value}
      if $parsed->{type} eq 'exact';
    return $entry >= $parsed->{from} && $entry <= $parsed->{to}
      if $parsed->{type} eq 'range';
    return $entry >= $parsed->{from}
      if $parsed->{type} eq 'open';
  }

  if ( $parsed->{format} eq 'mix' ) {
    unless (
      $self->_has_default_prefix
      && looks_like_number( $entry )
    ) {
      die "Entry must contain a prefix followed by a number (e.g., 'prefix15')."
      unless defined $entry_prefix && defined $entry_suffix;
    }

    return 0 if $entry_prefix && $entry_prefix ne $parsed->{prefix};

    if ( $entry_suffix ) {
      return $entry_suffix == $parsed->{value}
        if $parsed->{type} eq 'exact';
      return $entry_suffix >= $parsed->{from} && $entry_suffix <= $parsed->{to}
        if $parsed->{type} eq 'range';
      return $entry_suffix >= $parsed->{from}
        if $parsed->{type} eq 'open';
    }
  }

  return 0;
}

sub match {
  my ( $self, $range_string, @entries ) = @_;

  die "Invalid call: match() requires:\n"
   . "1) Range string (e.g. '1-10')\n"
   . "2) One or more versions to check (e.g. 5 or 'projA-15', 20)"
    unless defined $range_string && @entries;

  die 'Range string cannot be empty.' if $range_string eq '';

  my @ranges = split /,/, $range_string;

  foreach my $entry ( @entries ) {
    die 'Entry must be defined' unless defined $entry;
    die 'Entry must be a scalar' if ref $entry;
    die 'Entry cannot be an empty string' if $entry eq '';
    foreach my $range ( @ranges ) {
      return 1 if $self->_match( $range, $entry );
    }
  }

  return 0;
}

sub validate {
  my ( $self, $range_string ) = @_;

  die 'Range must be defined' unless defined $range_string;

  return 0 unless scalar @{ $self->prefixes };
  return 0 if $range_string eq '';

  my @ranges = split /,/, $range_string;

  my $in_validate = 1;
  foreach my $range ( @ranges ) {
    my $res = $self->_parse_range( $range, $in_validate );
    return 0 unless ref $res eq 'HASH';
  }

  return 1;
}

__PACKAGE__->meta->make_immutable;

1;
