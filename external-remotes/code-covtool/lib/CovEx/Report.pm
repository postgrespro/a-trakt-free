package CovEx::Report;

use strict;
use warnings;

use File::Spec;
use CovEx::Utils;

sub new {
    my ($class, $config) = @_;
    my $self = {
        config => $config,
    };
    bless $self, $class;
    return $self;
}

sub generate {
    my ($self, $results) = @_;
    
    my $report_file = File::Spec->catfile($self->{config}->{work_dir}, 'report.txt');
    
    open(my $fh, '>', $report_file) or die "Не могу создать $report_file: $!";
    
    print $fh "=" x 100 . "\n";
    print $fh "АНАЛИЗ ИЗМЕНЕНИЙ ФОРМАТА LCOV ФАЙЛОВ (ВКЛЮЧАЯ BRANCH COVERAGE)\n";
    print $fh "=" x 100 . "\n\n";
    
    # Сортируем версии от новых к старым
    my @sorted_versions = sort { CovEx::Utils::version_cmp($a, $b) } keys %$results;
    
    print $fh "Проанализировано версий: " . scalar(@sorted_versions) . "\n";
    print $fh "Диапазон: от " . $sorted_versions[-1] . " до " . $sorted_versions[0] . "\n";
    print $fh "Дата анализа: " . scalar(localtime()) . "\n\n";
    
    # Находим версии с изменениями
    my @changed_versions = grep { $results->{$_}{has_changes_vs_prev} } @sorted_versions;
    
    print $fh "ВЕРСИИ С ИЗМЕНЕНИЯМИ СТРУКТУРЫ LCOV: " . scalar(@changed_versions) . "\n";
    print $fh "-" x 100 . "\n";
    
    if (@changed_versions) {
        for my $version (@changed_versions) {
            print $fh "\nВерсия: $version\n";
            print $fh "Хэш содержимого: $results->{$version}{content_hash}\n";
            
            # Выводим информацию о покрытии
            my $struct = $results->{$version}{structure};
            if ($results->{$version}{changes_vs_prev}) {
                my $changes = $results->{$version}{changes_vs_prev};
                
                if ($changes->{record_types}{added} && @{$changes->{record_types}{added}}) {
                    print $fh "  Добавлены типы записей: " . join(', ', @{$changes->{record_types}{added}}) . "\n";
                }
                
                if ($changes->{record_types}{removed} && @{$changes->{record_types}{removed}}) {
                    print $fh "  Удалены типы записей: " . join(', ', @{$changes->{record_types}{removed}}) . "\n";
                }

                if ($changes->{format_changes} && keys %{$changes->{format_changes}}) {
                    print $fh "  Изменения в форматах записей:\n";
                    for my $type (sort keys %{$changes->{format_changes}}) {
                        my $fmt_changes = $changes->{format_changes}{$type};
                        if ($fmt_changes->{added} && @{$fmt_changes->{added}}) {
                            print $fh "    $type - новые форматы: " . join(', ', @{$fmt_changes->{added}}) . "\n";
                        }
                        if ($fmt_changes->{removed} && @{$fmt_changes->{removed}}) {
                            print $fh "    $type - удалены форматы: " . join(', ', @{$fmt_changes->{removed}}) . "\n";
                        }
                    }
                }
            }
        }
    } else {
        print $fh "Изменений структуры LCOV не обнаружено.\n";
    }

    close $fh;
    
    print "Текстовый отчет: $report_file\n";
}

1;
