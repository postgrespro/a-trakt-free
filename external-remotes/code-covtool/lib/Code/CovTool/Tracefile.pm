package Code::CovTool::Tracefile;

use strict;
use warnings;
use Moose;

=encoding utf8

=head1 NAME

Code::CovTool::Tracefile - валидация и парсинг LCOV tracefile

=head1 SYNOPSIS

  my $trace = Code::CovTool::Tracefile->new(
    tracefile => 'coverage.lcov',
    sources   => $cov_tool_sources,
  );
  $trace->validate_format;
  my $data = $trace->parse;

=head1 DESCRIPTION

Читает и валидирует формат LCOV, парсит в структуру данных покрытия (HashRef).
Использует Code::CovTool::Sources для проверки путей исходников.

=head1 CONSTRUCTOR

=head2 new

  my $trace = Code::CovTool::Tracefile->new(
    tracefile => 'coverage.lcov',
    sources   => $cov_tool_sources,
  );

Создаёт экземпляр для работы с одним LCOV-файлом.

=over 4

=item * B<tracefile> (обязательный)

Путь к файлу в формате LCOV.

=item * B<sources> (обязательный)

Объект L<Code::CovTool::Sources> для проверки путей исходников при парсинге.

=back

=head1 METHODS

=head2 parse

  my $data = $trace->parse;

Читает tracefile, для каждого пути вызывает L<Code::CovTool::Sources/check_path>,
собирает данные покрытия (DA, FN, FNDA и т.д.) в хэш по файлам. При ошибке
формата или несовпадении контрольных сумм завершает программу.

Возвращает ссылку на хэш: ключ — путь к файлу, значение — структура
{ sum => {...}, func => {...}, check => {...}, sumfnc => {...} }.

=head2 validate_format

  $trace->validate_format;

Проверяет синтаксис LCOV (SF, end_of_record, DA, FN, FNDA и т.д.) без загрузки
исходников. При ошибке завершает программу. Ничего не возвращает.

=cut

has 'tracefile' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has 'sources' => (
  is       => 'ro',
  isa      => 'Code::CovTool::Sources',
  required => 1,
);

sub validate_format {
  my ( $self ) = @_;
  my $tracefile = $self->tracefile;

  open my $fh, '<', $tracefile or die "ERROR: cannot open file $tracefile: $!\n";

  my $has_sf = 0;
  my $in_record = 0;
  my $line_num = 0;

  while ( my $line = <$fh> ) {
    $line_num++;
    chomp $line;
    $line =~ s/\s{2,}|\n//g;

    next if $line =~ /^\s*$/ || $line =~ /^#/;
    next if ( $line =~ /^TN:/ );

    if ( $line =~ /^SF:(.+)/ ) {
      my $sf = $1;
      die "ERROR:$tracefile:$line_num: SF inside record\n" if $in_record;
      $has_sf = 1;
      $in_record = 1;
      next;
    }

    if ( $line eq 'end_of_record' ) {
      die "ERROR:$tracefile:$line_num: end_of_record without SF\n" unless $in_record;
      $in_record = 0;
      next;
    }

    if ( $in_record ) {
      if ( $line =~ /^DA:/ ) {
        die "ERROR:$tracefile:$line_num: Invalid DA format (should be DA:<line>,<count>[,<checksum>])\n"
          unless $line =~ /^DA:\d+,\d+(?:,[^,\s]+)?$/;
        next;
      }

      if ( $line =~ /^FN:/ ) {
        die "ERROR:$tracefile:$line_num: Invalid FN format (should be FN:<line>,<name>)\n"
          unless $line =~ /^FN:\d+,[^,]+$/;
        next;
      }

      if ( $line =~ /^FNDA:/ ) {
        die "ERROR:$tracefile:$line_num: Invalid FNDA format (should be FNDA:<count>,<name>)\n"
          unless $line =~ /^FNDA:\d+,[^,]+$/;
        next;
      }

      if ( $line =~ /^BRDA:/ ) {
        die "ERROR:$tracefile:$line_num: Invalid BRDA format (should be BRDA:<line>,<block>,<branch>,<taken>)\n"
          unless $line =~ /^BRDA:\d+,\d+,\d+,(-|\d+)$/;
        next;
      }

      if ( $line =~ /^(LF|LH|FNF|FNH|BRF|BRH):/ ) {
        die "ERROR:$tracefile:$line_num: Invalid metric $1 format (should be <key>:<number>)\n"
          unless $line =~ /^(LF|LH|FNF|FNH|BRF|BRH):\d+$/;
        next;
      }

      next if ( $line =~ /^TN:/ );

      die "ERROR:$tracefile:$line_num: Unknown line format: $line\n";
    } else {
      die "ERROR:$tracefile:$line_num: Data outside of record (missing SF?)\n";
    }
  }

  die "ERROR:$tracefile: No valid SF entries found\n" unless $has_sf;
  die "ERROR:$tracefile: File ends in the middle of record\n" if $in_record;

  close $fh;
  return;
}

sub parse {
  my ( $self ) = @_;

  my $tracefile = $self->tracefile;
  my $sources   = $self->sources;

  print "Reading tracefile $tracefile\n";

  open my $fh, '<', $tracefile;

  my %result;
  my $filename         = undef;
  my $negative         = 0;
  my $sumcount         = {};
  my $funcdata         = {};
  my $checkdata        = {};
  my $sumfnccount      = {};
  my $line_num         = 0;

  while ( my $line = <$fh> ) {
    $line_num++;
    chomp $line;
    $line =~ s/\s{2,}|\n//g;

    if ( $line =~ /^[SK]F:(.*)/ ) {
      $filename = $1;

      $sources->check_path( $filename, $line_num );

      if ( $result{$filename} ) {
        $sumcount    = $result{$filename}->{sum};
        $funcdata    = $result{$filename}->{func};
        $checkdata   = $result{$filename}->{check};
        $sumfnccount = $result{$filename}->{sumfnc};
      } else {
        $sumcount     = {};
        $funcdata     = {};
        $checkdata    = {};
        $sumfnccount  = {};
      }

      next;
    }
    elsif ( $line =~ /^DA:(\d+),(-?\d+)(,[^,\s]+)?/ ) {
      my $count = $2 < 0 ? 0 : $2;
      $negative = 1 if ( $2 < 0 );

      $sumcount->{$1} += $count;

      if ( defined( $3 ) ) {
        my $line_checksum = substr( $3, 1 );

        die("ERROR: checksum mismatch at $filename:$1\n")
          if (
            defined( $checkdata->{$1} )
            && ( $checkdata->{$1} ne $line_checksum )
          );

        $checkdata->{$1} = $line_checksum;
      }

      next;
    }
    elsif ( $line =~ /^FN:(\d+),([^,]+)/ ) {
      $funcdata->{$2} = $1;

      $sumfnccount->{$2} = 0 if ( !defined( $sumfnccount->{$2} ) );

      next;
    }
    elsif ( $line =~ /^FNDA:(\d+),([^,]+)/ ) {
      $sumfnccount->{$2} += $1;

      next;
    }
    elsif ( $line =~ /^end_of_record/ ) {
      $self->_save_file_data(
        \%result,
        $filename,
        $sumcount,
        $funcdata,
        $checkdata,
        $sumfnccount,
      ) if $filename;

      $filename = undef;

      next;
    }

    next;
  }

  close $fh;

  warn "WARNING: negative counts found in tracefile $tracefile\n" if $negative;

  return \%result;
}

sub _save_file_data {
  my (
    $self, $result, $filename, $sumcount,
    $funcdata, $checkdata, $sumfnccount
  ) = @_;

  $result->{$filename} = {
    sum     => $sumcount,
    func    => $funcdata,
    check   => $checkdata,
    sumfnc  => $sumfnccount,
  };

  return;
}

1;
