use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'MooseX::RequiresClass',
    AUTHOR           => 'Nataraj',
    VERSION_FROM     => 'lib/MooseX/RequiresClass.pm',
    ABSTRACT_FROM    => 'lib/MooseX/RequiresClass.pm',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.008',

    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    PREREQ_PM => {
        'Moose' => '2.0000',   # Moose::Role, Moose::Util, Class::MOP, application classes
        'Carp'  => '0',
    },
    TEST_REQUIRES => {
        'Test::More' => '0',
    },

    META_MERGE => {
        'meta-spec' => { version => 2 },
        dynamic_config => 0,
    },

    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    clean => { FILES => 'MooseX-RequiresClass-*' },
);
