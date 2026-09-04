use strict; use warnings;
use Test::More;

{
    package Base1; use Moose; __PACKAGE__->meta->make_immutable;
    package Base2; use Moose; __PACKAGE__->meta->make_immutable;
    package RA; use Moose::Role; use MooseX::RequiresClass; requires_class 'Base1';
    package RB; use Moose::Role; use MooseX::RequiresClass; requires_class 'Base2';
}

# --- композит: with 'RA','RB' ---
ok( eval q{ package GBoth; use Moose; extends 'Base1','Base2'; with 'RA','RB'; 1 },
    'composite: both bases ok' );
ok( !eval q{ package MissB2; use Moose; extends 'Base1'; with 'RA','RB'; 1 },
    'composite: missing Base2 rejected' );
like( $@, qr/must inherit from Base2/, 'composite names missing base' );
ok( !eval q{ package MissBoth; use Moose; with 'RA','RB'; 1 },
    'composite: missing both rejected' );

# --- матрёшка: роль-в-роль ---
{
    package Outer; use Moose::Role; with 'RA';   # Outer несёт требование RA
}
ok( eval q{ package GOuter; use Moose; extends 'Base1'; with 'Outer'; 1 },
    'matryoshka: subclass ok' );
ok( !eval q{ package BOuter; use Moose; with 'Outer'; 1 },
    'matryoshka: non-subclass rejected' );
like( $@, qr/must inherit from Base1/, 'matryoshka names the base' );

# --- свой BUILD у потребителя не мешает (проверка на composition, не на BUILD) ---
ok( !eval q{ package OwnBuild; use Moose; extends 'Base1'; with 'RA','RB'; sub BUILD {} 1 },
    'own BUILD present, still rejected for missing Base2' );
like( $@, qr/must inherit from Base2/, 'own BUILD does not hide the check' );

done_testing;
