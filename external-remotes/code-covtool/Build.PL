use strict;
use warnings;

eval {
    require Module::Build;
    Module::Build->VERSION(0.42);
    1;
} or do {
    my $error = $@ || 'Unknown error';
    print <<"ERROR";
=== ERROR: Failed to load Module::Build ===
$error

This module requires Module::Build (version 0.42 or later).

Installation options:
1. Recommended method (requires internet):
   perl -MCPAN -e "install Module::Build"

2. Manual installation (offline):
   - Download Module::Build from https://metacpan.org/pod/Module::Build
   - Unpack and run:
     perl Makefile.PL
     make && make install

3. System package managers (Linux):
   sudo apt-get install libmodule-build-perl # Debian/Ubuntu
   sudo yum install perl-Module-Build        # RHEL/CentOS
   sudo dnf install perl-Module-Build        # Fedora

After installation, please rerun Build.PL
ERROR
    exit 1;
};

my $build = Module::Build->new(
    license             => 'perl',
    author              => 'therealgofman <therealgofman@mail.ru>',
    dist_abstract       => 'Code::CovTool - Module for processing LCOV coverage data',
    version_from        => 'lib/Code/CovTool.pm',
    module_name         => 'Code::CovTool',
    configure_requires  => {
        'Module::Build' => '0.42',
    },
    test_requires => {
        'Test::More'      => '0',
        'Test::Exception' => '0',
    },
    requires => {
        'Moose'         => '0',
        'Path::Tiny'    => '0',
        'Pod::Markdown' => '0',
        'Capture::Tiny' => '0',
        'DateTime'      => '0',
    },
    add_to_cleanup => ['Code-CovTool-*'],
    auto_features => {
        test_autorules => 0,
    },
);

$build->create_build_script;

# Генерируем README из POD с явным :utf8, чтобы не было "Wide character in print"
# (do_create_readme использует Pod::Text без binmode, из-за русского текста в POD — предупреждения)
_create_readme_utf8('lib/Code/CovTool.pm');

# Генерируем README.md через отдельный скрипт
print "Generate README.md...\n";

my $version = $build->dist_version || '0.01';
my $script_path = File::Spec->catfile('script', 'generate_readme.pl');

if (-f $script_path) {
    system($^X, $script_path, $version) == 0
        or warn "Failed to generate README.md\n";
} else {
    warn "Script not found: $script_path\n";
}

sub _create_readme_utf8 {
    my ($docfile) = @_;
    return unless defined $docfile && -f $docfile;

    eval {
        require Pod::Text;
        open my $fh, '>:utf8', 'README' or die "Cannot open README for writing: $!";
        Pod::Text::pod2text( $docfile, $fh );
        close $fh;
        print "README created from $docfile\n";
        1;
    } or do {
        warn "Could not create README: $@\n";
    };
}
