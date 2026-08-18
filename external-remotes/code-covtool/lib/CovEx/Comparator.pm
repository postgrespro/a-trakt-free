package CovEx::Comparator;

use strict;
use warnings;

use File::Spec;
use File::Basename;
use Digest::MD5 qw(md5_hex);

use CovEx::Utils;

sub new {
    my ( $class, $version ) = @_;
    my $self = {
        version => $version,
    };
    bless $self, $class;
    return $self;
}

sub analyze_lcov_file {
    my ($self, $file) = @_;
    
    return undef unless -f $file && -s $file;
    
    # Нормализуем файл
    my $normalized = $self->normalize_lcov_file($file);
    return undef unless $normalized;
    
    # Анализируем структуру
    my $structure = $self->analyze_lcov_structure($normalized->{raw_content});
    $normalized->{structure} = $structure;

    return $normalized;
}

sub normalize_lcov_file {
    my ($self, $file) = @_;

    open(my $in_fh, '<', $file) or do {
        warn "Не могу открыть $file: $!";
        return undef;
    };

    # Читаем сырое содержимое
    my $raw_content = do { local $/; <$in_fh> };
    close $in_fh;

    my @lines = split /\n/, $raw_content;

    # Собираем уникальные пути
    my %source_map;
    my @unique_paths;

    foreach my $line (@lines) {
        next if $line =~ /^\s*$/;
        if ($line =~ /^SF:(.+)$/ && !exists $source_map{$1}) {
            push @unique_paths, $1;
            $source_map{$1} = undef;
        }
    }

    # Сортируем пути по имени файла, затем по полному пути
    @unique_paths = sort {
        my $name_a = basename($a);
        my $name_b = basename($b);
        $name_a cmp $name_b || $a cmp $b;
    } @unique_paths;

    # Присваиваем номера
    my $counter = 0;
    foreach my $path (@unique_paths) {
        $source_map{$path} = ++$counter;
    }

    my @processed_lines;
    foreach my $line (@lines) {
        next if $line =~ /^\s*$/;

        if ($line =~ /^SF:(.+)$/) {
            my $original_path = $1;
            my $filename = basename($original_path);
            my $source_num = $source_map{$original_path};
            $line = "SF:SOURCE_$source_num/$filename";
        }

        push @processed_lines, $line;
    }

    # Сортируем обработанные строки
    my @sorted_lines = sort {
        my $type_a = ($a =~ /^([A-Z]+):/) ? $1 : '';
        my $type_b = ($b =~ /^([A-Z]+):/) ? $1 : '';

        # Сначала по типу
        my $type_cmp = $type_a cmp $type_b;
        return $type_cmp if $type_cmp != 0;

        # Для SF строк - по номеру SOURCE_
        if ($type_a eq 'SF') {
            my $num_a = ($a =~ /SOURCE_(\d+)/) ? $1 : 0;
            my $num_b = ($b =~ /SOURCE_(\d+)/) ? $1 : 0;
            return $num_a <=> $num_b;
        }

        # Для остальных - как есть
        return $a cmp $b;
    } @processed_lines;

    # Формируем нормализованный контент
    my $normalized_content = join("\n", @sorted_lines) . "\n";
    my $hash = md5_hex($normalized_content);

    my $normalized_file = $file . '.normalized';
    open(my $out_fh, '>', $normalized_file) or do {
        warn "Не могу создать $normalized_file: $!";
        return undef;
    };

    print $out_fh $normalized_content;
    close $out_fh;

    return {
        file        => $normalized_file,
        content     => $normalized_content,
        raw_content => $raw_content,
        hash        => $hash,
        source_map  => \%source_map
    };
}

sub analyze_lcov_structure {
    my ($self, $content) = @_;
    
    my @lines = split /\n/, $content;
    
    my %structure = (
        record_types => {},
        total_records => scalar(@lines),
        file_count => 0,
        da_count => 0,
        brda_count => 0,
        fn_count => 0,
        fnda_count => 0,
        brf_count => 0,
        brh_count => 0,
        formats => {},
    );

    if ( CovEx::Utils::is_version_greater_than_2_2_simple($self->{version}) ) {
        $structure{fna_count} = 0;
        $structure{fnl_count} = 0;
    }

    for my $line (@lines) {
        next if $line =~ /^\s*$/;
        
        # Определяем тип записи
        if ($line =~ /^([A-Z]+):/) {
            my $type = $1;
            $structure{record_types}{$type}++;
            
            if ($type eq 'SF') {
                $structure{file_count}++;
            } elsif ($type eq 'DA') {
                $structure{da_count}++;
            } elsif ($type eq 'BRDA') {
                $structure{brda_count}++;
            } elsif ($type eq 'BRF') {
                $structure{brf_count}++;       
            } elsif ($type eq 'BRH') {
                $structure{brh_count}++;           
            } elsif ($type eq 'FN') {
                $structure{fn_count}++;                
            } elsif ($type eq 'FNDA') {
                $structure{fnda_count}++;
            }
            if ( CovEx::Utils::is_version_greater_than_2_2_simple($self->{version}) ) {
                if($type eq 'FNA') {
                    $structure{fna_count}++;
                }
                elsif($type eq 'FNL') {
                    $structure{fnl_count}++;
                }
            }
            # Анализируем формат
            my $format = $self->_extract_record_format($line);
            if ($format) {
                $structure{formats}{$type}{$format}++;
            }
        }
    }

    return \%structure;
}

sub _extract_record_format {
    my ($self, $line) = @_;
    
    return unless $line =~ /^([A-Z]+):(.+)$/;
    my ($type, $content) = ($1, $2);
    
    my @parts = split(/,/, $content);
    my @format_parts;
    
    for my $part (@parts) {
        if ($part =~ /^-?\d+$/) {
            push @format_parts, 'N';  # Number
        } elsif ($part =~ /^-$/) {
            push @format_parts, '-';  # Dash
        } elsif ($part =~ /^[a-zA-Z0-9_\-\.\/]+$/) {
            push @format_parts, 'S';  # String
        } else {
            push @format_parts, 'X';  # Other
        }
    }
    
    return $type . ':' . join(',', @format_parts);
}

sub compare_structures {
    my ($self, $prev_struct, $prev_version, $curr_struct) = @_;

    my %comparison = (
        has_changes => 0,
        changes => {
            record_types => { added => [], removed => [] },
            counts => {},
            format_changes => {},
            coverage_changes => {},
        }
    );
    
    # Сравниваем типы записей
    my %prev_types = %{$prev_struct->{record_types}};
    my %curr_types = %{$curr_struct->{record_types}};
    
    # Находим новые типы
    for my $type (keys %curr_types) {
        if (!exists $prev_types{$type}) {
            push @{$comparison{changes}{record_types}{added}}, $type;
            $comparison{has_changes} = 1;
        }
    }
    
    # Находим удаленные типы
    for my $type (keys %prev_types) {
        if (!exists $curr_types{$type}) {
            push @{$comparison{changes}{record_types}{removed}}, $type;
            $comparison{has_changes} = 1;
        }
    }
    
    # Сравниваем количество записей для каждого типа
    for my $type (keys %prev_types) {
        if (exists $curr_types{$type}) {
            my $diff = $curr_types{$type} - $prev_types{$type};
            if ($diff != 0) {
                $comparison{changes}{counts}{$type} = $diff;
                $comparison{has_changes} = 1;
            }
        }
    }
    
    # Сравниваем форматы записей
    my %prev_formats = %{$prev_struct->{formats}};
    my %curr_formats = %{$curr_struct->{formats}};
    
    for my $type (keys %prev_formats) {
        if (exists $curr_formats{$type}) {
            my %prev_fmt = %{$prev_formats{$type}};
            my %curr_fmt = %{$curr_formats{$type}};
            
            # Находим новые форматы
            for my $fmt (keys %curr_fmt) {
                if (!exists $prev_fmt{$fmt}) {
                    $comparison{changes}{format_changes}{$type}{added} ||= [];
                    push @{$comparison{changes}{format_changes}{$type}{added}}, $fmt;
                    $comparison{has_changes} = 1;
                }
            }
            
            # Находим удаленные форматы
            for my $fmt (keys %prev_fmt) {
                if (!exists $curr_fmt{$fmt}) {
                    $comparison{changes}{format_changes}{$type}{removed} ||= [];
                    push @{$comparison{changes}{format_changes}{$type}{removed}}, $fmt;
                    $comparison{has_changes} = 1;
                }
            }
        }
    }
    
    # Проверяем специальные счетчики
    my @all_counts;
    my @special_counts = qw(file_count da_count brda_count brf_count brh_count);
    if (
        CovEx::Utils::is_version_greater_than_2_2_simple($self->{version})
        && $prev_version ne '2.2'
    ) {
         @all_counts = (@special_counts, qw(fna_count fnl_count));
    } else {
        @all_counts = (@special_counts, qw(fn_count fnda_count));
    }
    for my $count (@all_counts) {
        if ($prev_struct->{$count} != $curr_struct->{$count}) {
            $comparison{changes}{counts}{$count} = $curr_struct->{$count} - $prev_struct->{$count};
            $comparison{has_changes} = 1;
        }
    }

    return \%comparison;
}

1;
