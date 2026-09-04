use strict; use warnings;
use Test::More;

{
    package Base1; use Moose; __PACKAGE__->meta->make_immutable;
    package Base2; use Moose; __PACKAGE__->meta->make_immutable;
    package RA; use Moose::Role; use MooseX::RequiresClass; requires_class 'Base1';
    package RB; use Moose::Role; use MooseX::RequiresClass; requires_class 'Base2';
}

# opt-out на одиночном with: не-наследник проходит
ok( eval q{ package O1; use Moose; extends 'Base2';
            with 'RA' => { -no_baseclass_checks => 1 }; 1 },
    'single with + opt-out: skipped' );

# per-class: флаг на первом with гасит и последующий with без флага (нет утечки)
ok( eval q{ package O2; use Moose;
            with 'RA' => { -no_baseclass_checks => 1 };
            with 'RB'; 1 },
    'per-class opt-out suppresses later unflagged with too' );

# без флага проверка по-прежнему бьёт
ok( !eval q{ package O3; use Moose; extends 'Base2'; with 'RA'; 1 },
    'without flag, check still enforced' );
like( $@, qr/must inherit from Base1/, 'error still names base' );

# ограничение порядка: флаг на позднем with не отменяет ранний проверенный
ok( !eval q{ package O4; use Moose;
             with 'RA';                              # проверится и упадёт здесь
             with 'RB' => { -no_baseclass_checks => 1 }; 1 },
    'flag on a later with does not rescue an earlier requiring with' );
like( $@, qr/must inherit from Base1/, 'earlier with fails before the flag' );

# изоляция: метка строго по своему классу
ok(  eval q{ package O5a; use Moose; with 'RA' => { -no_baseclass_checks => 1 }; 1 }, 'O5a opted out' );
ok( !eval q{ package O5b; use Moose; extends 'Base2'; with 'RA'; 1 }, 'O5b (other class) still checked' );

done_testing;
