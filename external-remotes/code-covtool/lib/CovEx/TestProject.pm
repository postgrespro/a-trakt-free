package CovEx::TestProject;

use strict;
use warnings;

use File::Path qw(remove_tree make_path);
use File::Spec;
use File::Basename;
use Cwd qw(cwd abs_path);
use Capture::Tiny qw(capture_stdout);

sub new {
    my ($class, $config) = @_;
    my $self = {
        config => $config,
    };
    bless $self, $class;
    return $self;
}

sub prepare_test_environment {
    my ($self, $version) = @_;
    
    my $work_dir = $self->{config}->{work_dir};
    my $version_work_dir = File::Spec->catfile($work_dir, "test_build_$version");
    
    # Очищаем и создаем новую директорию
    remove_tree($version_work_dir) if -d $version_work_dir;
    make_path($version_work_dir);
    
    # Определяем корневую директорию проекта (где лежат include, src и т.д.)
    my $project_root = $self->_find_project_root();
    
    # Копируем всю структуру проекта
    $self->_copy_project_structure($project_root, $version_work_dir);
    
    return $version_work_dir;
}

sub _find_project_root {
    my $self = shift;
    
    my $source = $self->{config}->{test_project};
    
    # Если это файл - берем его директорию
    my $dir = (-f $source) ? dirname($source) : $source;
    
    # Поднимаемся на уровень выше если находимся в src/
    if (basename($dir) eq 'src') {
        $dir = dirname($dir);
    }
    
    # Проверяем что в найденной директории есть хотя бы include или src
    unless (-d File::Spec->catfile($dir, 'include') || 
            -d File::Spec->catfile($dir, 'src')) {
        warn "В директории $dir не найдены include/ или src/";
    }
    
    return $dir;
}

sub _copy_project_structure {
    my ($self, $src_dir, $dst_dir) = @_;
    
    system('cp', '-r', "$src_dir/.", $dst_dir) == 0 or
        warn "Не удалось скопировать $src_dir в $dst_dir: $?";
}

sub build_and_test_project {
    my ($self, $build_dir) = @_;
    
    my $original_dir = cwd();
    chdir($build_dir) or die "Не могу перейти в директорию $build_dir: $!";
    
    my $result = {
        success => 0,
        error => '',
        gcda_files => 0,
        gcno_files => 0
    };
    
    # Находим все .c файлы рекурсивно
    my @all_c_files = $self->_find_files_recursive('.', qr/\.c$/i);
    
    unless (@all_c_files) {
        $result->{error} = "Не найдены исходные файлы C";
        chdir($original_dir);
        return $result;
    }
    
    # Ищем main.c как основной файл
    my $main_file;
    my @other_files;
    
    for my $c_file (@all_c_files) {
        my $basename = basename($c_file);
        
        if ($basename eq 'main.c') {
            $main_file = $c_file;
        } elsif ($basename =~ /^main_/) {
            # Пропускаем все main_* файлы
            next;
        } else {
            push @other_files, $c_file;
        }
    }
    
    unless ($main_file) {
        $result->{error} = "Не найден файл main.c";
        chdir($original_dir);
        return $result;
    }
    
    # Определяем пути для include
    my @include_dirs = $self->_find_files_recursive('.', qr/^(?:include|inc)/);
    
    my $include_flags = $self->_build_include_flags(@include_dirs);
    
    print "Компилируем с флагами: $include_flags\n" if $self->{config}->{verbose};
    
    # Собираем все объектные файлы
    my $compile_result = $self->_compile_all_files(
        $main_file, \@other_files, $include_flags
    );
    
    unless ($compile_result->{success}) {
        $result->{error} = $compile_result->{error};
        chdir($original_dir);
        return $result;
    }
    
    # Линкуем если компиляция успешна
    my $link_success = $self->_link_executable(
        $compile_result->{object_files}
    );
    
    unless ($link_success) {
        $result->{error} = "Ошибка линковки";
        chdir($original_dir);
        return $result;
    }
    
    $result->{success} = 1;
    
    # Запускаем тестовое приложение если сборка успешна
    if ($result->{success} && -x './test_app') {
        $result = $self->_run_tests($result);
    } elsif ($result->{success}) {
        $result->{error} = "Исполняемый файл не найден";
        $result->{success} = 0;
    }
    
    chdir($original_dir);
    return $result;
}

sub _find_files_recursive {
    my ($self, $dir, $pattern) = @_;
    
    my @found;
    my @queue = ($dir);
    
    while (my $current_dir = shift @queue) {
        opendir(my $dh, $current_dir) or next;
        
        while (my $entry = readdir($dh)) {
            next if $entry =~ /^\./;
            
            my $path = File::Spec->catfile($current_dir, $entry);
            
            if (-d $path) {
                push @queue, $path;
                # Для поиска include директорий проверяем имя директории
                if (ref $pattern eq 'Regexp') {
                    push @found, $path if $entry =~ $pattern;
                }
            } elsif (-f $path && ref $pattern eq 'Regexp') {
                push @found, $path if $entry =~ $pattern;
            }
        }
        closedir($dh);
    }
    
    return @found;
}

sub _build_include_flags {
    my ($self, @include_dirs) = @_;
    
    my $include_flags = '';
    for my $inc_dir (@include_dirs) {
        $include_flags .= " -I$inc_dir";
    }
    
    # Добавляем стандартные директории если они существуют
    for my $dir ('./include', './src') {
        $include_flags .= " -I$dir" if -d $dir;
    }
    
    return $include_flags;
}

sub _compile_all_files {
    my ($self, $main_file, $other_files, $include_flags) = @_;
    
    my $result = {
        success => 0,
        error => '',
        object_files => [],
    };
    
    my @files_to_compile = ($main_file, @$other_files);
    
    for my $file (@files_to_compile) {
        my $obj_file = basename($file, '.c') . '.o';
        my $cmd = "gcc -c -fprofile-arcs -ftest-coverage $include_flags -o $obj_file $file 2>&1";
        
        if ($self->{config}->{verbose}) {
            print "Компиляция $file: $cmd\n";
        }
        
        my $exit_code = system($cmd);
        if ($exit_code == 0) {
            push @{$result->{object_files}}, $obj_file;
        } else {
            $result->{error} = "Ошибка компиляции $file";
            return $result;
        }
    }
    
    $result->{success} = 1;
    return $result;
}

sub _link_executable {
    my ($self, $object_files) = @_;
    
    my $link_cmd = "gcc -fprofile-arcs -ftest-coverage -o test_app " . 
                  join(' ', @$object_files) . " 2>&1";
    
    if ($self->{config}->{verbose}) {
        print "Линковка: $link_cmd\n";
    }
    
    my $exit_code = system($link_cmd);
    return $exit_code == 0;
}

sub _run_tests {
    my ($self, $result) = @_;
    
    # Проверяем наличие .gcno файлов
    my @gcno_files = glob("*.gcno");
    $result->{gcno_files} = scalar(@gcno_files);
    
    print "Создано .gcno файлов: $result->{gcno_files}\n" if $self->{config}->{verbose};
    
    if ($result->{gcno_files} == 0) {
        $result->{error} = "Не созданы .gcno файлы (флаги покрытия не сработали)";
        $result->{success} = 0;
        return $result;
    }
    
    print "Запускаем test_app...\n" if $self->{config}->{verbose};
    my $run_output = capture_stdout {
        system('./test_app');
    };
    
    print "Выход программы: $run_output\n" if $self->{config}->{verbose} && $run_output;
    
    # Проверяем наличие .gcda файлов
    my @gcda_files = glob("*.gcda");
    $result->{gcda_files} = scalar(@gcda_files);
    
    if ($result->{gcda_files} == 0) {
        $result->{error} = "Не сгенерированы файлы покрытия (.gcda)";
        $result->{success} = 0;
    } else {
        print "Сгенерировано .gcda файлов: $result->{gcda_files}\n" if $self->{config}->{verbose};
        
        # Выводим информацию о файлах покрытия для отладки
        if ($self->{config}->{verbose}) {
            for my $gcda (@gcda_files) {
                print "  Файл покрытия: $gcda (размер: " . (-s $gcda) . " байт)\n";
            }
        }
    }
    
    return $result;
}

1;
