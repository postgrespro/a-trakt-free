#!/usr/bin/perl

use strict;
use warnings;
use File::Path qw(make_path remove_tree);
use File::Basename qw(dirname);
use Cwd qw(abs_path);

my $samples_dir  = abs_path( dirname($0) . '/..' );
my $build_dir    = "$samples_dir/build";
my $coverage_dir = "$samples_dir/coverage";

remove_tree( $build_dir, $coverage_dir );
make_path( $build_dir, $coverage_dir );

my @tests = (
    {
        name    => 'simple',
        sources => 'src/core_functions.c src/advanced_coverage.c',
        main    => 'src/main_simple.c',
        output  => 'coverage/simple.LCOV',
    },
    {
        name    => 'full', 
        sources => 'src/core_functions.c src/advanced_coverage.c',
        main    => 'src/main_comprehensive.c',
        output  => 'coverage/full.LCOV',
    },
    {
        name    => 'special_cases',
        sources => 'src/special_cases.c',
        main    => 'src/main_special_cases.c',
        output  => 'coverage/special_cases.LCOV',
    },
    {
        name           => 'simple_nested',
        sources        => 'src/core_functions.c src/advanced_coverage.c',
        main           => 'src/backend/utils/main_simple.c',
        output         => 'coverage/simple_nested.LCOV',
        # Удаляем только main в корне src/, чтобы в LCOV остался src/backend/utils/main_simple.c
        remove_pattern => '*/src/main_*.c',
    },
);

print "=== Generating Clean Coverage Files ===\n";

foreach my $test ( @tests ) {
    print "Generating $test->{name}...\n";
    generate_test_coverage( $test );
}

# Генерация checksum тестов
generate_checksum_tests();

# Объединённый trace для t/08-cleaning.t / t/11-clip.t (clip_plan.LCOV)
generate_clip_plan();

# Fixture с дублирующимися SF для тестов add/append
generate_dublicate_sf_num();

remove_tree( $build_dir );

print "\n=== Generation Complete ===\n";
print "Template files (.LCOV) have been created in coverage/ directory\n";

sub generate_checksum_tests {
    print "Generating checksum tests...\n";
    
    # Генерируем оригинальную версию
    generate_test_coverage({
        name    => 'checksum_orig',
        sources => 'src/special_cases.c',
        main    => 'src/main_special_cases.c',
        output  => 'coverage/checksum_original.LCOV',
    });
    
    # Добавляем checksum в оригинальный файл
    add_checksum_to_file( "coverage/checksum_original.LCOV" );

    # Создаем конфликтный файл
    create_checksum_conflict();
}

sub generate_test_coverage {
    my ( $test ) = @_;
    capture_trace_to_file(
        {
            exe_name => $test->{name},
            sources  => $test->{sources},
            main     => $test->{main},
            out_file => $test->{output},
            remove   => $test->{remove_pattern} // '*/main_*.c',
            skip_remove => 0,
        }
    );
    apply_sf_path_template( $test->{output} );
}

# Сбор .info: компиляция, запуск, lcov capture, опционально lcov --remove.
sub capture_trace_to_file {
    my ($opt) = @_;

    chdir( $samples_dir ) or die "Cannot chdir: $!";

    my $exe = "build/$opt->{exe_name}";
    my $compile_cmd = "gcc -fprofile-arcs -ftest-coverage -I./include " .
      "$opt->{sources} $opt->{main} -o $exe";
    system( $compile_cmd ) == 0 or die "Compilation failed ($opt->{exe_name}): $!";

    system( "./$exe > /dev/null 2>&1" );

    my $temp_file = "coverage/temp.info";
    system( "/usr/bin/lcov --capture --directory build --output-file $temp_file --quiet" ) == 0
      or die "lcov capture failed ($opt->{exe_name})";

    if ( $opt->{skip_remove} ) {
        system( "cp $temp_file $opt->{out_file}" ) == 0 or die "cp trace failed";
    }
    else {
        my $remove = $opt->{remove} // '*/main_*.c';
        system( "/usr/bin/lcov --remove $temp_file '$remove' --output-file $opt->{out_file} --quiet" ) == 0
          or die "lcov --remove failed ($opt->{exe_name})";
    }

    system( "rm -f $temp_file build/*.gcda build/*.gcno" );
}

sub apply_sf_path_template {
    my ($file) = @_;
    system( "sed -i 's|^SF:$samples_dir\/|SF:\@PATH_TO_SOURCES\@\/|g' $file" );
}

# clip_plan.LCOV для t/08-cleaning.t и t/11-clip.t: четыре прогона (gcc+lcov), merge через lcov -a,
# затем удаление main_clip_plan.c из слияния; шаблон путей как у остальных .LCOV.
sub generate_clip_plan {
    print "Generating clip_plan (merged trace for 08-cleaning.t / 11-clip.t)...\n";

    my @parts = (
        {
            exe_name => 'clip_m1',
            sources  => 'src/core_functions.c src/advanced_coverage.c',
            main     => 'src/backend/utils/main_simple.c',
            out_file => 'coverage/_clip_m1.info',
            remove   => '*/src/main_*.c',
        },
        {
            exe_name => 'clip_m2',
            sources  => join( q{ }, qw(
                src/flat_one/only.c
                src/flat_two/a.c src/flat_two/b.c
                src/flat_many/x1.c src/flat_many/x2.c src/flat_many/x3.c
                src/backend/br_solo.c src/backend/br_a.c src/backend/br_b.c
                src/backend/br_m1.c src/backend/br_m2.c src/backend/br_m3.c
                src/backend/utils/u_extra.c src/backend/utils/u_more.c
            ) ),
            main     => 'src/main_clip_plan.c',
            out_file => 'coverage/_clip_m2.info',
            remove   => '*/main_*.c',
        },
        {
            exe_name    => 'clip_m3',
            sources     => 'src/core_functions.c src/advanced_coverage.c',
            main        => 'src/main_simple.c',
            out_file    => 'coverage/_clip_m3.info',
            skip_remove => 1,
        },
        {
            exe_name => 'clip_m4',
            sources  => 'src/core_functions.c src/advanced_coverage.c src/special_cases.c',
            main     => 'src/main.c',
            out_file => 'coverage/_clip_m4.info',
            skip_remove => 1,
        },
    );

    for my $p (@parts) {
        capture_trace_to_file($p);
    }

    my $merged = 'coverage/_clip_merged.info';
    system(
        "/usr/bin/lcov -a coverage/_clip_m1.info -a coverage/_clip_m2.info "
          . "-a coverage/_clip_m3.info -a coverage/_clip_m4.info -o $merged --quiet"
    ) == 0 or die "lcov merge (clip_plan) failed";

    my $no_driver = 'coverage/_clip_no_driver.info';
    system( "/usr/bin/lcov --remove $merged '*/main_clip_plan.c' -o $no_driver --quiet" ) == 0
      or die "lcov remove main_clip_plan.c failed";

    system( "cp $no_driver coverage/clip_plan.LCOV" ) == 0 or die;

    apply_sf_path_template('coverage/clip_plan.LCOV');

    system(
        'rm -f coverage/_clip_m1.info coverage/_clip_m2.info coverage/_clip_m3.info '
          . "coverage/_clip_m4.info $merged $no_driver"
    );

    print "clip_plan.LCOV ready.\n";
}

sub add_checksum_to_file {
    my ( $file ) = @_;

    my $content      = read_file( $file );
    my @lines        = split( "\n", $content );
    my $line_counter = 0;
    my $type         = 'orig';
    
    my @new_lines;
    
    foreach my $line ( @lines ) {
        if ( $line =~ /^DA:(\d+),(\d+)$/ ) {
            $line_counter++;
            my $line_num = $1;
            my $count    = $2;
            
            # Добавляем checksum
            my $checksum = "checksum_${type}_${line_counter}_123456";
            push @new_lines, "DA:$line_num,$count,$checksum";
        }
        else {
            push @new_lines, $line;
        }
    }
    write_file( $file, join( "\n", @new_lines ) );
}

sub create_checksum_conflict {
    my $orig_file      = "coverage/checksum_original.LCOV";
    my $conflict_file  = "coverage/checksum_conflict.LCOV";
    my $orig_content   = read_file( $orig_file );
    my @orig_lines     = split( "\n", $orig_content );
    my $added_conflict = 0;
    
    my @result_lines;
    foreach my $line ( @orig_lines ) {
        if ( $line =~ /^DA:4,1,checksum_orig_1_123456/ && !$added_conflict ) {
            # Добавляем КОНФЛИКТ: та же строка с другим checksum
            push @result_lines, $line; 
            push @result_lines, "DA:4,1,checksum_CONFLICT_123456";
            $added_conflict = 1;
        }
        else {
            push @result_lines, $line;
        }
    }
    
    write_file( $conflict_file, join( "\n", @result_lines ) );

    print "Real checksum conflict created!\n";
}

sub generate_dublicate_sf_num {
    print "Generating dublicate_sf_num fixture...\n";

    my $out_file = "coverage/dublicate_sf_num.LCOV";
    my $target_sf = '@PATH_TO_SOURCES@/src/core_functions.c';
    my $part_a = 'coverage/_dup_sf_a.info';
    my $part_b = 'coverage/_dup_sf_b.info';
    my $merged = 'coverage/_dup_sf_merged.info';

    # Два реальных запуска с разным поведением main дают два разных SF-блока.
    capture_trace_to_file(
        {
            exe_name => 'dup_sf_a',
            sources  => 'src/core_functions.c',
            main     => 'src/main_dup_core_min.c',
            out_file => $part_a,
            remove   => '*/main_*.c',
        }
    );
    capture_trace_to_file(
        {
            exe_name => 'dup_sf_b',
            sources  => 'src/core_functions.c',
            main     => 'src/main_dup_core.c',
            out_file => $part_b,
            remove   => '*/main_*.c',
        }
    );

    apply_sf_path_template($part_a);
    apply_sf_path_template($part_b);

    system("/usr/bin/lcov -a $part_a -a $part_b -o $merged --quiet") == 0
      or die "lcov merge (dublicate_sf_num) failed";

    # Для теста нам нужен минимальный fixture: ровно два блока одного SF.
    # rec_a = "сырой" блок из первого прогона, rec_b = агрегированный блок после lcov -a.
    my $rec_a = extract_record_by_sf( read_file($part_a), $target_sf );
    my $rec_b = extract_record_by_sf( read_file($merged), $target_sf );
    my $out = $rec_a . "\n" . $rec_b . "\n";
    write_file( $out_file, $out );

    system("rm -f $part_a $part_b $merged");
}

sub extract_record_by_sf {
    my ( $content, $target_sf ) = @_;
    # В merged/info много SF-записей; вырезаем одну целевую запись целиком
    # (от SF:... до end_of_record), чтобы собрать компактный fixture для duplicate-SF тестов.
    my @lines = split /\n/, $content;
    my @record;
    my $inside = 0;

    for my $line (@lines) {
        if ( $line =~ /^SF:(.*)$/ ) {
            $inside = ( $1 eq $target_sf ) ? 1 : 0;
        }
        next unless $inside;
        push @record, $line;
        if ( $line eq 'end_of_record' ) {
            return join "\n", @record;
        }
    }

    die "Failed to extract record for SF:$target_sf";
}

sub read_file { open my $fh, '<', shift; local $/; <$fh> }
sub write_file { open my $fh, '>', shift; print $fh shift; }
