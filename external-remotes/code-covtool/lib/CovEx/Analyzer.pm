package CovEx::Analyzer;

use strict;
use warnings;

use File::Spec;
use Cwd qw(abs_path cwd);

use CovEx::Config;
use CovEx::VersionManager;
use CovEx::TestProject;
use CovEx::FileGenerator;
use CovEx::Comparator;
use CovEx::Report;
use CovEx::Utils;

sub new {
    my ($class, $config) = @_;
    my $self = {
        config => $config,
        results => {},
    };
    bless $self, $class;
    return $self;
}

sub run {
    my $self = shift;
    
    # Создаем рабочий каталог
    $self->_setup_work_dir();
    
    # Получаем список версий LCOV
    my @versions = $self->_get_versions();
    
    unless (@versions) {
        die "Не найдено версий LCOV >= " . $self->{config}->{start_ver};
    }
    
    # Анализируем каждую версию
    $self->_analyze_versions(@versions);
    
    # Сохраняем результаты и генерируем отчет
    $self->_save_results();
    
    # Очистка
    $self->_cleanup() unless $self->{config}->{keep_repo};
    
    return 1;
}

sub _setup_work_dir {
    my $self = shift;
    
    my $work_dir = $self->{config}->{work_dir};
    unless (-d $work_dir) {
        require File::Path;
        File::Path::make_path($work_dir);
    }
    
    $self->{config}->{tmp_dir} = File::Spec->catfile(
        $work_dir, $self->{config}->{tmp_dir}
    );
    
    print "Рабочий каталог: $work_dir\n" if $self->{config}->{verbose};
}

sub _get_versions {
    my $self = shift;
    
    my $version_manager = CovEx::VersionManager->new($self->{config});
    return $version_manager->get_versions();
}

sub _analyze_versions {
    my ($self, @versions) = @_;
    
    my $prev_content = undef;
    my $prev_version = undef;
    
    for my $version (@versions) {
        my $comparator = CovEx::Comparator->new( $version );
        
        print "\n" . "=" x 60 . "\n";
        print "Анализ версии LCOV: $version\n";
        print "=" x 60 . "\n";
        
        # Генерируем LCOV файл для этой версии
        my $lcov_file = $self->_generate_lcov_for_version($version);
        
        unless ($lcov_file && -f $lcov_file) {
            warn "Не удалось получить lcov-файл для версии $version";
            next if $self->{config}->{skip_build_errors};
            last;
        }
        
        # Анализируем структуру файла
        my $analysis = $comparator->analyze_lcov_file($lcov_file);
        unless ($analysis) {
            warn "Не удалось проанализировать lcov-файл для версии $version";
            next;
        }
        
        # Сохраняем результаты
        $self->{results}{$version} = {
            lcov_file => $lcov_file,
            normalized_file => $analysis->{file},
            content_hash => $analysis->{hash},
            raw_content => $analysis->{raw_content},
            content => $analysis->{content},
            structure => $analysis->{structure},
            timestamp => time(),
        };
        
        # Выводим информацию о структуре
        $self->_print_structure_info($version, $analysis->{structure});
        
        # Сравниваем с предыдущей версией
        if (defined $prev_content) {
            $self->_compare_with_previous(
                $version, $prev_version, 
                $analysis, $comparator
            );
        } else {
            print "✓ Это первая проанализированная версия\n";
            $self->{results}{$version}{is_first} = 1;
        }
        
        $prev_content = $analysis->{content};
        $prev_version = $version;
    }
}

sub _generate_lcov_for_version {
    my ($self, $version) = @_;
    
    my $file_generator = CovEx::FileGenerator->new($self->{config});
    return $file_generator->generate_for_version($version);
}

sub _print_structure_info {
    my ($self, $version, $structure) = @_;
    
    print "Структура LCOV файла для версии $version:\n";
    print "  Типы записей: " . join(', ', sort keys %{$structure->{record_types}}) . "\n";
    print "  Всего записей: " . $structure->{total_records} . "\n";
    print "  Файлов (SF): " . $structure->{file_count} . "\n";
    print "  Строк (DA): " . $structure->{da_count} . "\n";
    print "  Веток (BRDA): " . $structure->{brda_count} . "\n";
    if ( CovEx::Utils::is_version_greater_than_2_2_simple( $version ) ) {
        print "  Функций (FNA): " . $structure->{fna_count} . "\n";
        print "  Вызовов функций (FNL): " . $structure->{fnl_count} . "\n";
    } else {
        print "  Функций (FN): " . $structure->{fn_count} . "\n";
        print "  Вызовов функций (FNDA): " . $structure->{fnda_count} . "\n";
    }
}

sub _compare_with_previous {
    my ($self, $version, $prev_version, $analysis, $comparator) = @_;
    
    my $prev_struct = $self->{results}{$prev_version}{structure};
    my $curr_struct = $analysis->{structure};
    
    print "\nСравнение с версией $prev_version:\n";
    
    my $comparison = $comparator->compare_structures(
        $prev_struct, $prev_version, $curr_struct
    );

    if ($comparison->{has_changes}) {
        print "⚠️  Обнаружены изменения в структуре LCOV!\n";
        $self->_print_comparison_details($comparison);
        $self->{results}{$version}{has_changes_vs_prev} = 1;
        $self->{results}{$version}{changes_vs_prev} = $comparison->{changes};
    } else {
        print "✓ Структура LCOV не изменилась\n";
        $self->{results}{$version}{has_changes_vs_prev} = 0;
    }
    
    # Сравниваем хэши содержимого
    if ($self->{results}{$prev_version}{content_hash} ne $analysis->{hash}) {
        print "⚠️  Изменилось содержимое LCOV файла (разные хэши)\n";
        $self->{results}{$version}{content_hash_changed} = 1;
    }
}

sub _print_comparison_details {
    my ($self, $comparison) = @_;
    
    my $changes = $comparison->{changes};
    
    if ($changes->{record_types}) {
        my $rt_changes = $changes->{record_types};
        if (@{$rt_changes->{added}}) {
            print "  Добавлены типы записей: " . join(', ', @{$rt_changes->{added}}) . "\n";
        }
        if (@{$rt_changes->{removed}}) {
            print "  Удалены типы записей: " . join(', ', @{$rt_changes->{removed}}) . "\n";
        }
    }
    
    if ($changes->{counts}) {
        my $count_changes = $changes->{counts};
        for my $type (sort keys %$count_changes) {
            my $diff = $count_changes->{$type};
            if ($diff != 0) {
                my $sign = $diff > 0 ? '+' : '';
                print "  Изменено количество записей $type: $sign$diff\n";
            }
        }
    }
    
    if ($changes->{format_changes} && keys %{ $changes->{format_changes} }) {
        print "  Изменения в формате записей:\n";
        for my $type (sort keys %{$changes->{format_changes}}) {
            my $formats = $changes->{format_changes}{$type};
            if (@{$formats->{added}}) {
                print "    $type - добавлены форматы: " . join(', ', @{$formats->{added}}) . "\n";
            }
            if (@{$formats->{removed}}) {
                print "    $type - удалены форматы: " . join(', ', @{$formats->{removed}}) . "\n";
            }
        }
    }
}

sub _save_results {
    my $self = shift;
    
    if (%{$self->{results}}) {
        # Сохраняем JSON
        $self->_save_json_results();
        
        # Генерируем отчет
        my $report = CovEx::Report->new($self->{config});
        $report->generate($self->{results});
    } else {
        warn "Нет результатов для анализа!";
    }
}

sub _save_json_results {
    my $self = shift;
    
    require JSON::PP;
    
    my $json_file = File::Spec->catfile(
        $self->{config}->{work_dir},
        $self->{config}->{results_file}
    );
    
    my %json_data;
    for my $version (sort { CovEx::Utils::version_cmp($b, $a) } keys %{$self->{results}}) {
        $json_data{$version} = {
            content_hash => $self->{results}{$version}{content_hash},
            lcov_file => $self->{results}{$version}{lcov_file},
            normalized_file => $self->{results}{$version}{normalized_file},
            timestamp => $self->{results}{$version}{timestamp},
            structure => $self->{results}{$version}{structure},
            raw_content => $self->{results}{$version}{raw_content},
        };
        
        if ($self->{results}{$version}{is_first}) {
            $json_data{$version}{is_first} = 1;
        }
        
        if ($self->{results}{$version}{has_changes_vs_prev}) {
            $json_data{$version}{has_changes_vs_prev} = 1;
            $json_data{$version}{changes_vs_prev} = $self->{results}{$version}{changes_vs_prev};
        }
        
        if ($self->{results}{$version}{content_hash_changed}) {
            $json_data{$version}{content_hash_changed} = 1;
        }
    }
    
    open(my $fh, '>', $json_file) or die "Не могу создать $json_file: $!";
    print $fh JSON::PP->new->pretty->encode(\%json_data);
    close $fh;
    
    print "\n" . "=" x 60 . "\n";
    print "Результаты сохранены в: $json_file\n";
}

sub _cleanup {
    my $self = shift;
    
    print "\nОчистка временных файлов...\n" if $self->{config}->{verbose};
    
    my $work_dir = $self->{config}->{work_dir};
    
    require File::Path;
    opendir(my $dh, $work_dir) or return;
    while (my $entry = readdir($dh)) {
        next unless $entry =~ /^(test_build_|lcov_)/;
        my $dir = File::Spec->catfile($work_dir, $entry);
        File::Path::remove_tree($dir) if -d $dir;
    }
    closedir($dh);
    
    # Удаляем клон репозитория если не нужно сохранять
    if (-d $self->{config}->{tmp_dir} && !$self->{config}->{keep_repo}) {
        File::Path::remove_tree($self->{config}->{tmp_dir});
    }
}

1;
