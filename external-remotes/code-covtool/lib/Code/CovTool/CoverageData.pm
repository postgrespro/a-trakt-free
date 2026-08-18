package Code::CovTool::CoverageData;

use strict;
use warnings;

=encoding utf8

=head1 NAME

Code::CovTool::CoverageData - операции над данными покрытия (merge, export, zero)

=head1 SYNOPSIS

  my $merged = Code::CovTool::CoverageData::merge_datasets( [ $data1, $data2 ] );
  my $lcov_str = Code::CovTool::CoverageData::to_lcov( $summary_hash );
  Code::CovTool::CoverageData::zero_file_data( $file_data_ref );

=head1 DESCRIPTION

Пакет с функциями для работы со структурой данных покрытия:
объединение наборов, сериализация в LCOV, обнуление счётчиков.
Используется в Code::CovTool для объединения данных, экспорта в LCOV и обнуления при remove.

=head1 FUNCTIONS

=head2 merge_datasets

  my $merged = Code::CovTool::CoverageData::merge_datasets( \@datasets );

Объединяет несколько наборов данных покрытия в один: для каждого файла суммирует
счётчики строк (DA) и функций (FNDA), объединяет check и метаданные функций.
При несовпадении контрольных сумм завершает программу.

=over 4

=item * B<\@datasets> — массив ссылок на хэши (каждый хэш: путь к файлу => { sum, func, check, sumfnc })

=back

Возвращает ссылку на хэш объединённых данных.

=head2 to_lcov

  my $str = Code::CovTool::CoverageData::to_lcov( $summary );

Формирует строку в формате LCOV по хэшу данных покрытия (SF, DA, FN, FNDA, FNF, FNH, LH, LF, end_of_record).

=over 4

=item * B<$summary> — хэш данных покрытия (как у L</merge_datasets>)

=back

Возвращает строку, пригодную для genhtml и аналогичных утилит.

=head2 zero_file_data

  Code::CovTool::CoverageData::zero_file_data( $file_data );

Обнуляет счётчики строк и функций в одной записи покрытия (мутирует переданный хэш).
Используется в методе remove из Code::CovTool.

=over 4

=item * B<$file_data> — ссылка на хэш { sum => {...}, sumfnc => {...} } (и др. ключи без изменений)

=back

Ничего не возвращает.

=cut

sub merge_datasets {
  my ( $datasets ) = @_;

  my $result = {};

  for my $tracedata ( @$datasets ) {
    for my $filename ( keys %$tracedata ) {
      if ( $result->{$filename} && $tracedata->{$filename} ) {
        my ( $checkdata, $funcdata, $sumfnccount, $sumcount ) = combine_data_entries(
          $result->{$filename},
          $tracedata->{$filename},
          $filename
        );
        $result->{$filename}->{sum}    = $sumcount;
        $result->{$filename}->{check}  = $checkdata;
        $result->{$filename}->{func}   = $funcdata;
        $result->{$filename}->{sumfnc} = $sumfnccount;
      } else {
        $result->{$filename} = $tracedata->{$filename};
      }
    }
  }

  return $result;
}

sub to_lcov {
  my ( $res ) = @_;

  my @chunks;

  foreach my $filename ( keys %{$res} ) {
    push @chunks, "SF:$filename\n";

    my ( $l_hit, $l_found ) = ( 0, 0 );

    foreach my $lnum ( keys %{ $res->{$filename}->{sum} } ) {
      push @chunks,
        "DA:$lnum"
        . ',' . $res->{$filename}->{sum}->{$lnum}
        . (
          $res->{$filename}->{check}->{$lnum}
            ? ',' . $res->{$filename}->{check}->{$lnum} : ''
        ) . "\n";
      $l_found++;
      $l_hit++ if $res->{$filename}->{sum}->{$lnum} > 0;
    }

    foreach my $fnc_name ( keys %{ $res->{$filename}->{func} } ) {
      push @chunks, "FN:" . $res->{$filename}->{func}->{$fnc_name} . ",$fnc_name\n";
    }

    foreach my $fnc_name ( keys %{ $res->{$filename}->{sumfnc} } ) {
      push @chunks, "FNDA:" . $res->{$filename}->{sumfnc}->{$fnc_name} . ",$fnc_name\n";
    }

    my ( $f_found, $f_hit ) = get_func_found_and_hit( $res->{$filename}->{sumfnc} );

    push @chunks, "FNF:$f_found\nFNH:$f_hit\nLH:$l_hit\nLF:$l_found\n";

    push @chunks, "end_of_record\n";
  }
  return join '', @chunks;
}

sub zero_file_data {
  my ( $file_data ) = @_;
  return unless $file_data;

  for my $line ( keys %{ $file_data->{sum} } ) {
    $file_data->{sum}{$line} = 0;
  }
  for my $fn ( keys %{ $file_data->{sumfnc} } ) {
    $file_data->{sumfnc}{$fn} = 0;
  }
}

sub combine_data_entries {
  my ( $left, $right, $filename ) = @_;

  my $checkdata   = merge_checksums( $left->{check}, $right->{check}, $filename );
  my $funcdata    = merge_func_data( $left->{func}, $right->{func}, $filename );
  my $sumfnccount = add_fnccount( $left->{sumfnc}, $right->{sumfnc} );
  my $sumcount    = add_counts( $left->{sum}, $right->{sum} );

  return ( $checkdata, $funcdata, $sumfnccount, $sumcount );
}

sub add_counts {
  my ( $data1_ref, $data2_ref ) = @_;
  my %result;
  my $line;
  my $data1_count;
  my $data2_count;

  foreach $line ( keys( %$data1_ref ) ) {
    $data1_count = $data1_ref->{$line};
    $data2_count = $data2_ref->{$line};

    $data1_count += $data2_count if ( defined( $data2_count ) );

    $result{$line} = $data1_count;
  }

  foreach $line ( keys( %$data2_ref ) ) {
    next if ( defined( $data1_ref->{$line} ) );

    $result{$line} = $data2_ref->{$line};
  }

  return \%result;
}

sub add_fnccount {
  my ( $fnccount1, $fnccount2 ) = @_;

  my %result;
  my $function;

  if ( defined( $fnccount1 ) ) {
    %result = %{$fnccount1};
  }

  foreach $function ( keys %{ $fnccount2 } ) {
    $result{$function} += $fnccount2->{$function};
  }

  return \%result;
}

sub merge_func_data {
  my ( $funcdata1, $funcdata2, $filename ) = @_;

  my %result;
  my $func;

  if ( defined( $funcdata1 ) ) {
    %result = %{$funcdata1};
  }

  foreach $func ( keys %{ $funcdata2 } ) {
    my $line1 = $result{$func};
    my $line2 = $funcdata2->{$func};

    if (
      defined( $line1 )
      && ( $line1 != $line2 )
    ) {
      warn "WARNING: function data mismatch at $filename:$line2\n";
      next;
    }

    $result{$func} = $line2;
  }

  return \%result;
}

sub merge_checksums {
  my ( $ref1, $ref2, $filename ) = @_;

  my %result;
  my $line;

  foreach $line ( keys %{ $ref1 } ) {
    if (
      defined( $ref2->{$line} )
      && ( $ref1->{$line} ne $ref2->{$line} ) )
    {
      die "ERROR: checksum mismatch at $filename:$line\n";
    }
    $result{$line} = $ref1->{$line};
  }

  foreach $line ( keys %{ $ref2 } ) {
    $result{$line} = $ref2->{$line};
  }

  return \%result;
}

sub get_func_found_and_hit {
  my $sumfnccount = shift;

  my $function;
  my $f_found;
  my $f_hit;

  $f_found = scalar( keys( %{ $sumfnccount } ) );
  $f_hit = 0;

  foreach $function ( keys( %{ $sumfnccount } ) ) {
    $f_hit++ if ( $sumfnccount->{$function} > 0 );
  }

  return ( $f_found, $f_hit );
}

1;
