#!/usr/bin/perl

# Скрипт для генерации и объединения Планов Тестирования
# Формирует план тестирования на основе Pod'a:
#
# =head1 GROUP: NAME
# =head1 SUBGROUP: NAME
# =head1 TYPE: POSITIVE/NEGATIVE
# =head1 TEST: Про что тест
# =cut
#
# Использование:
#   ./generate_plan.pl filename.t            # генерация плана для одного файла
#   ./generate_plan.pl --combine             # объединение всех планов в один
#   ./generate_plan.pl --combine file1 file2 # объединение указанных планов

use strict;
use warnings;
use Cwd;
use Getopt::Long;

my $combine_mode = 0;
my $help_mode = 0;

GetOptions(
    'combine' => \$combine_mode,
    'help'    => \$help_mode,
) or die "Неверные параметры. Используйте --help для справки.\n";

if ( $help_mode ) {
    print_help();
    exit 0;
}

if ( $combine_mode ) {
    combine_plans();
} else {
    generate_single_plan();
}

sub print_help {
    print <<"HELP";
Использование:
  $0 filename.t                    # генерация плана для одного файла
  $0 --combine                     # объединение всех *_test_plan.txt в один
  $0 --combine file1.txt file2.txt # объединение указанных файлов планов
HELP
}

sub combine_plans {
    my $output_file = 'combined_test_plan.txt';
    my @input_files = @ARGV;

    unless ( @input_files ) {
         @input_files = grep { $_ ne 'combined_test_plan.txt' } glob( "*_test_plan.txt" );
        die "No *_test_plan.txt files found in current directory\n" unless @input_files;
    }

    @input_files = sort @input_files;

    my $current_dir = getcwd();
    open my $out_fh, '>', "$current_dir/$output_file" or die "Cannot create $output_file: $!";

    print $out_fh "ОБЪЕДИНЕННЫЙ ПЛАН ТЕСТИРОВАНИЯ\n";
    print $out_fh "Создан: " . localtime() . "\n";
    print $out_fh "=" x 60 . "\n\n";

    my $file_count = 0;
    foreach my $file (@input_files) {
        $file_count++;

        print "Добавляю: $file\n";

        if ( $file_count > 1 ) {
            print $out_fh "\n" . "-" x 60 . "\n";
        }

        open my $in_fh, '<', $file or die "Cannot open $file: $!";
        while ( my $line = <$in_fh> ) {
            print $out_fh $line;
        }
        close $in_fh;
    }

    close $out_fh;

    print "\nГотово! Объединено $file_count файлов в $output_file\n";
}

sub generate_single_plan {
    my $input_file = $ARGV[0] or die "Usage: $0 filename.t\n";

    die "File $input_file does not exist\n" unless -e $input_file;
    die "File must have .t extension\n" unless $input_file =~ /\.t$/;

    my %test_plan;
    parse_test_file($input_file, \%test_plan);
    generate_reports(\%test_plan, $input_file);
}

sub parse_test_file {
    my ( $file, $plan ) = @_;

    open my $fh, '<', $file or die "Cannot open $file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my $current_group = 'UNGROUPED';
    my $current_subgroup = 'DEFAULT';
    my $current_type = 'DEFAULT';
    my $current_test = {};

    while ( $content =~ /(=head1\s+(\w+):\s*(.*?))(?==head1|=cut|\z)/gs ) {
        my ( $full_match, $key, $value ) = ( $1, $2, $3 );

        $value =~ s/^\s+|\s+$//g;
        
        if ( $key eq 'GROUP' ) {
            if ( %$current_test ) {
                save_test_case( $current_group, $current_subgroup, $current_type, $current_test, $plan );
                $current_test = {};
            }
            $current_group = $value;
            $current_subgroup = 'DEFAULT';
            $current_type = 'DEFAULT';
        }
        elsif ( $key eq 'SUBGROUP' ) {
            if ( %$current_test ) {
                save_test_case( $current_group, $current_subgroup, $current_type, $current_test, $plan );
                $current_test = {};
            }
            $current_subgroup = $value;
        }
        elsif ( $key eq 'TYPE' ) {
            if ( %$current_test ) {
                save_test_case( $current_group, $current_subgroup, $current_type, $current_test, $plan );
                $current_test = {};
            }
            $current_type = $value;
        }
        elsif ( $key eq 'TEST' ) {
            if ( %$current_test ) {
                save_test_case( $current_group, $current_subgroup, $current_type, $current_test, $plan );
            }
            $current_test = { 
                name => $value,
                file => $file,
                group => $current_group,
                subgroup => $current_subgroup,
                type => $current_type
            };
        }
        else {
            $current_test->{ lc($key) } = $value if %$current_test;
        }
    }

    save_test_case( $current_group, $current_subgroup, $current_type, $current_test, $plan ) if %$current_test;
}

sub save_test_case {
    my ( $group, $subgroup, $type, $test, $plan ) = @_;
    
    push @{ $plan->{$group}->{subgroups}->{$subgroup}->{types}->{$type}->{test_cases} }, $test;
    $plan->{$group}->{count}++;
    $plan->{$group}->{subgroups}->{$subgroup}->{count}++;
    $plan->{$group}->{subgroups}->{$subgroup}->{types}->{$type}->{count}++;
}

sub generate_reports {
    my ( $plan, $input_file ) = @_;

    generate_text_report( $plan, $input_file );
    generate_summary( $plan, $input_file );
}

sub generate_text_report {
    my ( $plan, $input_file ) = @_;

    my $current_dir = getcwd();

    my $output_file = $input_file;
    $output_file =~ s/\.t$/_test_plan.txt/;

    open my $fh, '>', "$current_dir/$output_file" or die "Cannot create $output_file: $!";

    print $fh "ПЛАН ТЕСТИРОВАНИЯ\n";
    print $fh "Файл: $input_file\n";
    print $fh "=" . "=" x 60 . "\n\n";

    foreach my $group ( sort keys %$plan ) {
        print $fh "$group:\n";
        print $fh "-" x 40 . "\n";

        foreach my $subgroup ( sort keys %{ $plan->{$group}->{subgroups} } ) {
            print $fh "\t$subgroup:\n";

            foreach my $type ( sort keys %{ $plan->{$group}->{subgroups}->{$subgroup}->{types} } ) {
                print $fh "\t\t$type:\n";

                my $counter = 1;
                foreach my $test ( @{ $plan->{$group}->{subgroups}->{$subgroup}->{types}->{$type}->{test_cases} } ) {
                    print $fh "\t\t\t$counter. $test->{name}\n";
                    print $fh "\n";
                    $counter++;
                }
            }
            print $fh "\n";
        }
        print $fh "\n";
    }

    close $fh;
    print "Отчет создан: $output_file\n";
}

sub generate_summary {
    my ( $plan, $input_file ) = @_;

    my $total_tests = 0;
    my %group_stats;
    my %subgroup_stats;
    my %type_stats;

    foreach my $group ( keys %$plan ) {
        $group_stats{$group} = $plan->{$group}->{count};
        $total_tests += $plan->{$group}->{count};

        foreach my $subgroup ( keys %{ $plan->{$group}->{subgroups} } ) {
            $subgroup_stats{$subgroup} += $plan->{$group}->{subgroups}->{$subgroup}->{count};

            foreach my $type ( keys %{ $plan->{$group}->{subgroups}->{$subgroup}->{types} } ) {
                $type_stats{$type} += $plan->{$group}->{subgroups}->{$subgroup}->{types}->{$type}->{count};
            }
        }
    }

    print "\nСВОДКА ТЕСТ ПЛАНА для файла $input_file:\n";
    print "=" . "=" x 50 . "\n";
    print "Всего тест-кейсов: $total_tests\n\n";

    print "По группам:\n";
    foreach my $group ( sort keys %group_stats ) {
        printf "  %-20s: %d\n", $group, $group_stats{$group};
    }

    print "\nПо подгруппам:\n";
    foreach my $subgroup ( sort keys %subgroup_stats ) {
        printf "  %-20s: %d\n", $subgroup, $subgroup_stats{$subgroup};
    }

    print "\nПо типам:\n";
    foreach my $type ( sort keys %type_stats ) {
        printf "  %-20s: %d\n", $type, $type_stats{$type};
    }
}
