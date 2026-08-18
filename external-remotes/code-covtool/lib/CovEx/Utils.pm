package CovEx::Utils;

use strict;

use File::Spec;
use File::Basename;
use Cwd qw(abs_path);

sub is_version_greater_than_2_2_simple {
    my ($version) = shift;
    
    # head всегда считается более новой версией
    return 1 if $version eq 'head';

    my @parts = split(/\./, $version);
    my @target = (2, 2, 0);
    
    # Сравниваем каждую часть
    for my $i (0..2) {
        my $part = $parts[$i] || 0;
        my $target_part = $target[$i] || 0;
        
        return 1 if $part > $target_part;
        return 0 if $part < $target_part;
    }
    
    return 0;  # Версии равны
}

sub version_cmp {
    my ($a, $b) = @_;

    # head всегда считается самой новой версией
    return -1 if $a eq 'head' && $b ne 'head';  # a (head) > b
    return 1 if $b eq 'head' && $a ne 'head';   # a < b (head)
    return 0 if $a eq 'head' && $b eq 'head';   # head == head
    
    # Удаляем возможный префикс 'v'
    $a =~ s/^v//;
    $b =~ s/^v//;
    
    my @a_parts = split /\./, $a;
    my @b_parts = split /\./, $b;
    
    # Дополняем нулями для сравнения
    my $max_len = @a_parts > @b_parts ? @a_parts : @b_parts;
    while (@a_parts < $max_len) { push @a_parts, 0; }
    while (@b_parts < $max_len) { push @b_parts, 0; }
    
    # Сравниваем по частям
    for my $i (0..$#a_parts) {
        return 1 if $a_parts[$i] < $b_parts[$i];  # a < b
        return -1 if $a_parts[$i] > $b_parts[$i]; # a > b
    }
    
    return 0;  # равны
}

sub find_project_root {
    my ($start_dir) = @_;

    # Если не указана начальная директория, используем текущую
    my $check = $start_dir ? abs_path($start_dir) : abs_path('.');

    # Если start_dir - это файл, берем его директорию
    if (-f $check) {
        $check = dirname($check);
    }

    # Ищем корень проекта: директорию, содержащую lib/ и t/
    while ($check ne File::Spec->rootdir()) {
        if (-d File::Spec->catdir($check, 'lib') &&
            -d File::Spec->catdir($check, 't')) {
            return $check;
        }
        $check = File::Spec->catdir($check, File::Spec->updir());
    }

    # Если не нашли, возвращаем начальную директорию
    return $start_dir ? abs_path($start_dir) : abs_path('.');
}

1;

