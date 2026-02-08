#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/../lib";

use SDL::Ranges;
use Test::More;
use Test::Exception;

my $rc = SDL::Ranges->new( prefixes => [ '', 'projA-', 'projB-' ] );

#########
# MATCH #
#########

ok ( $rc->match( '1', '1' ), 'точечный диапазон' );
ok ( $rc->match( 'projA-1', 'projA-1'), 'точечный диапазон' );

ok ( $rc->match( '1-3', '2' ), 'закрытый диапазон' );
ok ( $rc->match( 'projA-(1-3)', 'projA-2' ), 'закрытый диапазон' );
ok ( $rc->match( 'projB-(10-15)', 'projB-13' ), 'закрытый диапазон' );

ok ( $rc->match( '30+', '31' ), 'открытый диапазон' );
ok ( $rc->match( 'projA-12+', 'projA-13' ), 'открытый диапазон' );
ok ( $rc->match( 'projB-12+', 'projB-13' ), 'открытый диапазон' );
ok ( ! $rc->match( 'projB-12+', 'projA-13' ), 'не совпадают, так как разные проекты (projA vs projB)' );
ok ( ! $rc->match( 'projA-12', '12' ), 'В префиксах у нас есть пустой префикс, должно вернуть false' );

ok ( $rc->match( '1,2,3', '2' ), 'комбинированный вариант' );
ok ( $rc->match( '1,10-20,30+', '11' ), 'комбинированный вариант' );
ok ( $rc->match( 'projA-1,projA-2,projA-3,projA-13', 'projA-2' ), 'комбинированный вариант' );
ok ( $rc->match( 'projA-1,projA-(10-20),projA-30+', 'projA-11' ), 'комбинированный вариант' );
ok ( $rc->match( '7,15-19,projA-11,projB-(14-15),projB-19+', 'projB-20' ), 'комбинированный вариант' );
ok ( $rc->match( '1,10-20,30+,13,17,projB-14,projB-15+', 'projB-16' ), 'комбинированный вариант' );

# Два возможных варианта, match вернет true если подходит хотя бы один из них.
ok ( $rc->match( '13,17,projA-(13-19),projB-14', 'projA-17', '17' ), 'комбинированный вариант с 2-я вариантами' );

throws_ok(
    sub { $rc->match },
    qr/Invalid call: match()/,
    'должно вызвать ошибку, нельзя вызывать без аргументов'
);

throws_ok(
    sub { $rc->match( '1-10' ) },
    qr/Invalid call: match()/,
    'должно вызвать ошибку, нельзя вызывать только передавая диапазон'
);

throws_ok(
    sub { $rc->match( '1-10', undef ) },
    qr/Entry must be defined/,
    'должно вызвать ошибку, нельзя передавать на проверку undef'
);

throws_ok(
    sub { $rc->match( '1-10', '' ) },
    qr/Entry cannot be an empty string/,
    'должно вызвать ошибку, нельзя передавать пустую строку на проверку'
);

throws_ok(
    sub { $rc->match( '', '1' ) },
    qr/Range string cannot be empty./,
    'должно вызвать ошибку, нельзя использвоать пустую строку в диапазоне'
);

throws_ok(
    sub { $rc->match( '1-10', [ '13' ] ) },
    qr/Entry must be a scalar/,
    'должно вызвать ошибку, можно только скаляры подавать на вход'
);

throws_ok(
    sub { $rc->match( 'projA-12', 'fd' ) },
    qr/Entry must contain a prefix followed by a number/,
    'должно вызвать ошибку, версия должна обязательно иметь на последнем месте цифру.'
);

throws_ok(
    sub {
        my $rc = SDL::Ranges->new( prefixes => [ 'projA-', 'projB-' ] );
        $rc->match( 'projA-12', 'fd' );
    },
    qr/Entry must contain a prefix followed by a number/,
    'должно вызвать ошибку, версия должна обязательно иметь на последнем месте цифру.'
);

throws_ok(
    sub {
        my $rc = SDL::Ranges->new( prefixes => [ 'projA-', 'projB-' ] );
        $rc->match( 'projA-12', '12' );
    },
    qr/Entry must contain a prefix followed by a number/,
    'должно вызвать ошибку, версия должна обязательно иметь на последнем месте цифру.'
);

throws_ok(
    sub {
        my $rc = SDL::Ranges->new( prefixes => [ 'projA-' ] );
        $rc->match( '12', '12' )
    },
    qr/Invalid range format/,
    "должно вызвать ошибку, в префиксах отсутсвует ('')"
);

throws_ok(
    sub {
        my $rc = SDL::Ranges->new();
        $rc->match( '12', 'projA-12' );
    },
    qr/prefix 'projA-' not found in prefixes./,
    "должно вызвать ошибку, в префиксах отсутсвует ('proj-A')"
);

# Эквивалентно SDL::Ranges->new( prefixes => [''] )
my $im = SDL::Ranges->new();
ok ( $im->match( '1', '1' ), 'точечный диапазон, конструктор без префиксов' );
ok ( $im->match( '1-3', '2' ), 'закрытый диапазон, конструктор без префиксов' );
ok ( $im->match( '30+', '31' ), 'открытый диапазон, конструктор без префиксов' );

throws_ok(
    sub { $im->match( 'projA-(16-18)', '17' ) },
    qr/Invalid range format/,
    'должно вызвать ошибку (у нас дефолтный конструктор, а проверяем диапазон с префиксом)'
);

############
# VALIDATE #
############
# У $rc prefixes => [ '', 'projA-', 'projB-' ]
ok ( $rc->validate( '1' ), 'валидный точечный диапазон' );
ok ( $rc->validate( '10-20' ), 'валидный закрытый диапазон' );
ok ( $rc->validate( '30+' ), 'валидный открытый диапазон' );
ok ( $rc->validate( '13,17' ), 'валидный комбинированый вариант' );
ok ( $rc->validate( 'projB-15,projB-16' ), 'валидный комбинированый вариант' );
ok ( $rc->validate( 'projB-14' ), 'валидный точечный диапазон' );
ok ( $rc->validate( 'projB-(15-16)' ), 'валидный закрытый диапазон' );
ok ( $rc->validate( 'projB-17+' ), 'валидный открытый диапазон' );
ok ( $rc->validate( '1,10-20,30+,13,17,projB-14,projB-(15-16),projB-17+' ), 'валидный составной диапазон' );

$rc = SDL::Ranges->new( prefixes => [] );
ok ( !$rc->validate( '' ), 'пустой range всегда false' );
ok ( !$rc->validate( '1' ), 'с пустым префиксом, не валидно' );
ok ( !$rc->validate( '10-20' ), 'с пустым префиксом, не валидно' );
ok ( !$rc->validate( '30+' ), 'с пустым префиксом, не валидно' );
ok ( !$rc->validate( 'projB-1' ), 'с пустым префиксом, не валидно' );
ok ( !$rc->validate( 'projB-(10-15)' ), 'с пустым префиксом, не валидно' );
ok ( !$rc->validate( 'projB-10+' ), 'с пустым префиксом, не валидно' );
ok ( !$rc->validate( '1,10-20,30+,13,17,projB-14,projB-(15-16),projB-17+' ), 'с пустым префиксом, не валидно' );

$rc = SDL::Ranges->new( prefixes => [ 'projA-' ] );
ok ( !$rc->validate( '12' ), "В префиксах отсутствует '', должно вернуть false" );

throws_ok(
    sub { $rc->validate },
    qr/Range must be defined/,
    'должно вызвать ошибку, нельзя вызывать без аргументов'
);

done_testing();
