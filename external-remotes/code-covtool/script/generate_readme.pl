#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../lib";

use CovEx::Utils;
use File::Spec;
use Cwd qw(abs_path);

my $project_root = CovEx::Utils::find_project_root($FindBin::Bin);

# Получаем версию из аргументов или извлекаем из модуля
my $version = shift;
unless ($version) {
    $version = _extract_version($project_root);
}

# Генерируем README.md в корне проекта
_generate_readme($project_root, $version);

# Генерируем README.md в lib/Code/CovTool для подмодулей
_generate_covtool_readme($project_root, $version);

sub _extract_version {
    my $project_root = shift;
    my $module_file = File::Spec->catfile($project_root, 'lib', 'Code', 'CovTool.pm');

    unless (-f $module_file) {
        die "Module file not found: $module_file\n";
    }

    open my $fh, '<', $module_file or die "Cannot open $module_file: $!\n";
    while (my $line = <$fh>) {
        if ($line =~ /our\s+\$VERSION\s*=\s*['"]([^'"]+)['"]/) {
            close $fh;
            return $1;
        }
    }
    close $fh;

    warn "Version not found in module, using default\n";
    return '0.01';
}

sub _generate_readme {
    my ($project_root, $version) = @_;

    eval {
        require Pod::Markdown;

        my $module_file = File::Spec->catfile($project_root, 'lib', 'Code', 'CovTool.pm');
        my $readme_file = File::Spec->catfile($project_root, 'README.md');

        my $parser = Pod::Markdown->new;
        $parser->parse_from_file($module_file);

        open my $fh, '>', $readme_file or die "Cannot open $readme_file: $!\n";
        binmode($fh, ':utf8');
        print $fh "# Code::CovTool\n\n";
        print $fh "**Version:** $version\n\n";
        print $fh "---\n\n";
        print $fh $parser->as_markdown;
        print $fh "\n---\n\n";
        print $fh "*Automatically generated from POD documentation*\n";
        close $fh;

        print "README.md generated successfully!\n";

        1;
    } or do {
        die "Failed to generate README.md: $@\nMake sure that Pod::Markdown is installed\n";
    };
}

sub _generate_covtool_readme {
    my ($project_root, $version) = @_;

    eval {
        require Pod::Markdown;

        my $covtool_dir = File::Spec->catdir($project_root, 'lib', 'Code', 'CovTool');
        my $readme_file = File::Spec->catfile($covtool_dir, 'README.md');

        unless (-d $covtool_dir) {
            warn "Code::CovTool directory not found, skipping lib/Code/CovTool/README.md\n";
            return;
        }

        opendir my $dh, $covtool_dir or die "Cannot open directory $covtool_dir: $!\n";
        my @modules = sort grep { /\.pm\z/ } readdir $dh;
        closedir $dh;

        unless (@modules) {
            warn "No .pm files in $covtool_dir, skipping README.md\n";
            return;
        }

        open my $fh, '>', $readme_file or die "Cannot open $readme_file: $!\n";
        binmode($fh, ':utf8');
        print $fh "# Code::CovTool — подмодули\n\n";
        print $fh "**Версия:** $version\n\n";
        print $fh "---\n\n";

        for my $module (@modules) {
            my $module_path = File::Spec->catfile($covtool_dir, $module);
            my $name = $module;
            $name =~ s/\.pm\z//;

            my $parser = Pod::Markdown->new( perldoc_url_prefix => '' );
            $parser->parse_from_file($module_path);

            my $md = $parser->as_markdown;
            $md = _strip_perldoc_links($md);

            print $fh "## $name\n\n";
            print $fh $md;
            print $fh "\n\n";
        }

        print $fh "---\n\n";
        print $fh "*Сгенерировано из POD документации подмодулей*\n";
        close $fh;

        print "lib/Code/CovTool/README.md generated successfully!\n";

        1;
    } or do {
        warn "Failed to generate lib/Code/CovTool/README.md: $@\n";
    };
}

# Убираем ссылки на metacpan и pod-якоря из сгенерированного Markdown.
# В POD подмодулей есть перекрёстные ссылки (L<Code::CovTool::Sources>, L<Code::CovTool/remove> и т.д.),
# и Pod::Markdown по умолчанию превращает их в URL на metacpan.org или в якоря вида Module%3A%3AName.
# Так как пока модуль не публикуется, такие ссылки в README бесполезны и ведут в никуда.
# Оставляем только текст ссылки (например, «Code::CovTool::Sources») без обёртки в [text](url).
sub _strip_perldoc_links {
    my ($md) = @_;
    return $md if !defined $md;
    # [text](https://metacpan.org/...) или [text](Code::CovTool%3A%3ASources) -> text
    $md =~ s/\[([^\]]+)\]\((?:https:\/\/metacpan\.org[^)]*|[^)]*%3A[^)]*)\)/$1/g;
    return $md;
}
