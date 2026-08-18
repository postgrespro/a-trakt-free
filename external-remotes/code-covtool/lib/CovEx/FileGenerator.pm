package CovEx::FileGenerator;

use strict;
use warnings;

use File::Path;
use File::Spec;
use File::Basename;
use File::Copy qw(copy);
use Cwd qw(cwd);
use Capture::Tiny qw(capture_stdout);

use CovEx::TestProject;

sub new {
    my ($class, $config) = @_;
    my $self = {
        config => $config,
    };
    bless $self, $class;
    return $self;
}

sub generate_for_version {
    my ($self, $version) = @_;
    
    my $version_dir = File::Spec->catfile($self->{config}->{work_dir}, "lcov_$version");
    
    File::Path::make_path($version_dir);
    
    # Получаем бинарник LCOV
    my $lcov_bin = $self->_get_lcov_binary($version, $version_dir);
    
    unless ($lcov_bin && -x $lcov_bin) {
        warn "LCOV бинарник не найден для версии $version";
        return undef;
    }
    
    # Подготавливаем тестовую среду
    my $test_project = CovEx::TestProject->new($self->{config});
    my $test_dir = $test_project->prepare_test_environment($version);
    
    # Собираем и запускаем тестовый проект
    my $build_result = $test_project->build_and_test_project($test_dir);
    
    unless ($build_result->{success}) {
        warn "Ошибка сборки/тестирования проекта: " . $build_result->{error};
        return undef if !$self->{config}->{skip_build_errors};
    }
    
    # Генерируем lcov-файл
    my $lcov_file = File::Spec->catfile($version_dir, "coverage_$version.info");
    chdir($test_dir);
    
    # Устанавливаем переменные окружения для Perl
    my $lib_dir = File::Spec->catfile($version_dir, 'lib');
    my $bin_dir = File::Spec->catfile($version_dir, 'bin');
    
    local $ENV{PATH} = "$bin_dir:$ENV{PATH}";
    if (-d $lib_dir) {
        local $ENV{PERL5LIB} = $lib_dir . ($ENV{PERL5LIB} ? ":$ENV{PERL5LIB}" : "");
    }

    print "Генерируем LCOV отчет...\n" if $self->{config}->{verbose};
    
    # Пробуем разные команды для генерации
    my $exit = 0;
    my $output = '';
    
    # Сначала пробуем с флагом --verbose
    $output = capture_stdout {
        $exit = system("lcov --capture --directory . --output-file $lcov_file --verbose --rc lcov_branch_coverage=1 2>&1");
    };
    
    if ($exit != 0 || !-f $lcov_file || -z $lcov_file) {
        print "Пробуем без --verbose...\n" if $self->{config}->{verbose};
        $output = capture_stdout {
            $exit = system("lcov --capture --directory . --output-file $lcov_file --rc lcov_branch_coverage=1 2>&1");
        };
    }

    if ($self->{config}->{verbose}) {
        print "Вывод LCOV (verbose): $output\n";
    }

    chdir($self->{config}->{work_dir});
    
    if (-f $lcov_file && -s $lcov_file) {
        print "✓ LCOV файл создан: " . basename($lcov_file) . "\n";
        print "  Размер: " . (-s $lcov_file) . " байт\n" if $self->{config}->{verbose};
        
        # Показываем первые несколько строк для проверки
        if ($self->{config}->{verbose}) {
            open(my $fh, '<', $lcov_file) or warn "Не могу открыть $lcov_file: $!";
            my $line_count = 0;
            while (my $line = <$fh>) {
                last if $line_count++ >= 10;
                chomp $line;
                print "  $line\n";
            }
            close($fh);
        }
        
        return $lcov_file;
    } else {
        warn "✗ Не удалось создать LCOV файл для версии $version";
        if ($self->{config}->{verbose}) {
            print "  LCOV бинарник: $lcov_bin\n";
            print "  Выход LCOV: $output\n" if $output;
            print "  Код завершения: $exit\n";
        }
        return undef;
    }
}

sub _get_lcov_binary {
    my ($self, $version, $install_dir) = @_;
    
    my $tmp_dir = $self->{config}->{tmp_dir};
    
    chdir($tmp_dir);

    # Для head ветки используем master, иначе используем тег версии
    my $checkout_target = ($version eq 'head') ? 'master' : "v$version";

    my $exit = system('git', 'checkout', '-f', $checkout_target);
    
    if ($exit != 0) {
        warn "Не удалось переключиться на $checkout_target";
        chdir($self->{config}->{work_dir});
        return undef;
    }
    
    # Ищем бинарник lcov
    my $lcov_bin;
    my $found_bin_dir;
    
    # Проверяем разные возможные местоположения
    my @possible_paths = (
        'lcov',                         # В текущей директории
        'bin/lcov',                     # В bin/
        'usr/bin/lcov',                 # В usr/bin/
        'usr/local/bin/lcov',           # В usr/local/bin/
    );
    
    for my $path (@possible_paths) {
        if (-x $path) {
            $lcov_bin = File::Spec->rel2abs($path);
            $found_bin_dir = dirname($lcov_bin);
            last;
        }
    }

    unless ($lcov_bin && $found_bin_dir) {
        chdir($self->{config}->{work_dir});
        return undef;
    }
    
    print "Найден LCOV бинарник: $lcov_bin\n" if $self->{config}->{verbose};
    print "Директория с бинарником: $found_bin_dir\n" if $self->{config}->{verbose};
    
    # Создаем директорию для версии
    my $version_bin_dir = File::Spec->catfile($install_dir, 'bin');
    File::Path::make_path($version_bin_dir);
    
    # Копируем ВСЕ файлы из директории с бинарником
    print "Копируем все файлы из $found_bin_dir в $version_bin_dir...\n" if $self->{config}->{verbose};
    
    opendir(my $bin_dh, $found_bin_dir) or do {
        warn "Не удалось открыть директорию $found_bin_dir: $!";
        chdir($self->{config}->{work_dir});
        return undef;
    };
    
    # Сначала собираем список файлов для копирования
    my @files_to_copy;
    while (my $entry = readdir($bin_dh)) {
        next if $entry =~ /^\./;  # Пропускаем скрытые файлы
        push @files_to_copy, $entry;
    }
    closedir($bin_dh);
    
    # Копируем каждый файл
    for my $entry (@files_to_copy) {
        my $src_file = File::Spec->catfile($found_bin_dir, $entry);
        my $dst_file = File::Spec->catfile($version_bin_dir, $entry);
        
        if (-f $src_file) {
            copy($src_file, $dst_file) or warn "Не удалось скопировать $src_file: $!";
            
            # Делаем исполняемыми все скрипты и бинарники
            if ($self->_is_executable_file($src_file, $entry)) {
                chmod 0755, $dst_file;
                print "  Сделал исполняемым: $entry\n" if $self->{config}->{verbose};
            }
        } elsif (-d $src_file) {
            system('cp', '-r', $src_file, $version_bin_dir);
            
            # Делаем все файлы в поддиректории исполняемыми
            if (-d $dst_file) {
                $self->_set_executable_permissions($dst_file);
            }
        }
    }
    
    # Проверяем, что у нас есть бинарник lcov в целевой директории
    my $local_bin = File::Spec->catfile($version_bin_dir, 'lcov');
    unless (-x $local_bin) {
        $local_bin = File::Spec->catfile($version_bin_dir, basename($lcov_bin));
    }
    
    unless (-x $local_bin) {
        warn "Не удалось найти скопированный бинарник lcov";
        chdir($self->{config}->{work_dir});
        return undef;
    }
    
    # Копируем lib
    $self->_copy_lib($found_bin_dir, $install_dir);
    
    # Делаем все основные утилиты LCOV исполняемыми
    $self->_make_lcov_tools_executable($version_bin_dir);
    
    chdir($self->{config}->{work_dir});

    # Возвращаем путь к локальному бинарнику
    return $local_bin;
}

sub _is_executable_file {
    my ($self, $file, $entry) = @_;
    
    # По расширению
    return 1 if $entry =~ /\.(sh|pl|py)$/i;
    
    # По имени (основные утилиты LCOV)
    return 1 if $entry =~ /^(lcov|genhtml|gendesc|geninfo|genpng|gen-coverage-py)$/i;

    return 0;
}

sub _set_executable_permissions {
    my ($self, $dir) = @_;
    
    return unless -d $dir;
    
    opendir(my $dh, $dir) or return;
    while (my $entry = readdir($dh)) {
        next if $entry =~ /^\./;
        
        my $path = File::Spec->catfile($dir, $entry);
        
        if (-f $path) {
            if ($self->_is_executable_file($path, $entry)) {
                chmod 0755, $path;
            }
        } elsif (-d $path) {
            $self->_set_executable_permissions($path);
        }
    }
    closedir($dh);
}

sub _copy_lib {
    my ($self, $found_bin_dir, $install_dir) = @_;
    
    # Определяем базовую директорию для поиска зависимостей
    my $base_dir = dirname($found_bin_dir);
    
    # Ищем и копируем lib директорию
    my @possible_lib_locations = (
        File::Spec->catfile($base_dir, 'lib'),
        File::Spec->catfile($found_bin_dir, '..', 'lib'),
        'lib',
        File::Spec->catfile($base_dir, '..', 'lib'),
        File::Spec->catfile($self->{config}->{tmp_dir}, 'lib'),
    );
    
    my $version_lib_dir = File::Spec->catfile($install_dir, 'lib');
    for my $lib_location (@possible_lib_locations) {
        if (-d $lib_location && !-d $version_lib_dir) {
            print "Копируем lib директорию: $lib_location -> $version_lib_dir\n" if $self->{config}->{verbose};
            system('cp', '-r', $lib_location, $install_dir);
            last;
        }
    }
}

sub _make_lcov_tools_executable {
    my ($self, $bin_dir) = @_;
    
    # Проверяем все основные утилиты LCOV
    my @lcov_tools = qw(lcov genhtml gendesc geninfo);
    for my $tool (@lcov_tools) {
        my $tool_path = File::Spec->catfile($bin_dir, $tool);
        if (-f $tool_path && !-x $tool_path) {
            chmod 0755, $tool_path;
            print "Сделал исполняемым: $tool\n" if $self->{config}->{verbose};
        }
    }
}

1;
