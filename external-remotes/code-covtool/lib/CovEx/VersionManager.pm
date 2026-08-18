package CovEx::VersionManager;

use strict;
use warnings;

use Capture::Tiny qw(capture_stdout);
use File::Spec;
use File::Path qw(make_path remove_tree);
use Cwd qw(cwd);

sub new {
    my ($class, $config) = @_;
    my $self = {
        config => $config,
    };
    bless $self, $class;
    return $self;
}

sub get_versions {
    my $self = shift;
    
    # Клонируем или обновляем репозиторий
    $self->_prepare_repository();
    
    # Получаем все теги (версии)
    my $stdout = $self->_get_git_tags();
    
    # Фильтруем версии по минимальной
    my @versions = $self->_filter_versions($stdout);
    
    return @versions;
}

sub _prepare_repository {
    my $self = shift;
    
    my $tmp_dir = $self->{config}->{tmp_dir};
    
    if (-d $tmp_dir) {
        print "Обновляем репозиторий LCOV...\n" if $self->{config}->{verbose};
        chdir($tmp_dir);
        system('git', 'fetch', '--all', '--tags', '--force');
    } else {
        print "Клонируем репозиторий LCOV...\n" if $self->{config}->{verbose};
        system('git', 'clone', '--branch', 'master', 
               $self->{config}->{lcov_repo}, $tmp_dir);
        chdir($tmp_dir);
        system('git', 'fetch', '--all', '--tags', '--force');
    }
}

sub _get_git_tags {
    my $self = shift;
    
    return capture_stdout { 
        system('git', 'tag', '--list', '--sort', 'version:refname');
    };
}

sub _filter_versions {
    my ($self, $text) = @_;
    
    my @result;
    my $min_version = $self->{config}->{start_ver};
    
    # Ищем все версии
    while ($text =~ /v(\d+(?:\.\d+)+)(?:-([\w\.\-]+))?/g) {
        my ($version, $tag) = ($1, $2 || '');
        
        # Пропускаем не-релизы
        next if $tag;
        
        # Сравниваем с минимальной версией
        if ($self->_version_greater_or_equal($version, $min_version)) {
            push @result, $version
        }
    }

    push @result, 'head';

    return @result;
}

sub _version_greater_or_equal {
    my ($self, $version, $min_version) = @_;
    
    # Разбиваем на части
    my @curr_parts = split /\./, $version;
    my @target_parts = split /\./, $min_version;
    
    # Дополняем нулями
    while (@curr_parts < @target_parts) { push @curr_parts, 0; }
    while (@target_parts < @curr_parts) { push @target_parts, 0; }
    
    # Сравниваем
    for my $i (0 .. $#curr_parts) {
        if ($curr_parts[$i] > $target_parts[$i]) {
            return 1;
        } elsif ($curr_parts[$i] < $target_parts[$i]) {
            return 0;
        }
    }
    
    return 1;  # Версии равны
}

1;
