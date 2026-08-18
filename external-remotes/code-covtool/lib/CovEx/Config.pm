package CovEx::Config;

use strict;
use warnings;

use File::Basename;
use File::Spec;
use Cwd qw(abs_path);
use Getopt::Long;
use Pod::Usage;

use CovEx::Utils;

sub new {
    my ($class, %args) = @_;

    my $project_root = CovEx::Utils::find_project_root();

    my $self = {
        # Конфигурация по умолчанию
        lcov_repo         => 'https://github.com/linux-test-project/lcov.git',
        start_ver         => '1.16',
        work_dir          => 'lcov_analysis',
        test_project      => File::Spec->catdir($project_root, 't', 'samples', 'src'),
        test_include      => File::Spec->catdir($project_root, 't', 'samples', 'include'),
        results_file      => 'changes.json',
        tmp_dir           => 'tmp_lcov',
        verbose           => 0,
        keep_repo         => 0,
        skip_build_errors => 0,
        %args,  # Переопределяем значениями из аргументов
    };
    
    bless $self, $class;
    return $self;
}

sub parse_command_line {
    my $self = shift;
    
    GetOptions(
        'project|p=s'   => \$self->{test_project},
        'include|i=s'   => \$self->{test_include},
        'start|s=s'     => \$self->{start_ver},
        'work-dir|w=s'  => \$self->{work_dir},
        'output|o=s'    => \$self->{results_file},
        'verbose|v'     => \$self->{verbose},
        'keep-repo|k'   => \$self->{keep_repo},
        'skip-errors'   => \$self->{skip_build_errors},
        'help|h'        => sub { pod2usage(-verbose => 2, -exitval => 0) },
    ) or pod2usage(2);
    
    pod2usage(1) unless $self->{test_project};
    
    # Преобразуем относительный путь в абсолютный
    $self->{test_project} = abs_path($self->{test_project});
    unless (-d $self->{test_project}) {
        die "Тестовый проект не найден: " . $self->{test_project};
    }
    
    # Определяем директорию с заголовочными файлами
    $self->_find_include_directory();
    
    # Преобразуем рабочий каталог в абсолютный путь
    $self->{work_dir} = abs_path($self->{work_dir});
    
    return $self;
}

sub _find_include_directory {
    my $self = shift;
    
    if ($self->{test_include}) {
        $self->{test_include} = abs_path($self->{test_include});
        die "Директория с заголовочными файлами не найдена: " . $self->{test_include} 
            unless -d $self->{test_include};
    } else {
        # Пробуем найти include рядом с проектом
        my $possible_include = File::Spec->catfile(
            dirname($self->{test_project}), '..', 'include'
        );
        if (-d $possible_include) {
            $self->{test_include} = abs_path($possible_include);
        }
    }
}

1;
