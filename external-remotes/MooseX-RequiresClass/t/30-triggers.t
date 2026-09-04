use strict; use warnings;
use Test::More;

{
    package Base1; use Moose; __PACKAGE__->meta->make_immutable;
    package RA; use Moose::Role; use MooseX::RequiresClass; requires_class 'Base1';
}

# --- immutable: проверка на make_immutable, ДО создания объекта ---
my $stage = eval q{
    package Imm; use Moose; with 'RA';           # не наследник
    __PACKAGE__->meta->make_immutable;
    'reached-after-make_immutable';
};
ok( !$stage, 'immutable non-subclass rejected' );
like( $@, qr/must inherit from Base1/, 'immutable rejection names base' );

# --- immutable-наследник собирается и инлайнится без предупреждений ---
my @warns;
{
    local $SIG{__WARN__} = sub { push @warns, "@_" };
    eval q{ package ImmOk; use Moose; extends 'Base1'; with 'RA';
            __PACKAGE__->meta->make_immutable; ImmOk->new; 1 };
}
ok( !$@, 'immutable subclass builds' );
is( scalar(@warns), 0, 'no constructor-inlining warnings' ) or diag "warns: @warns";

# --- чужой immutable-класс без наших ролей: инлайнинг не задет ---
my @warns2;
{
    local $SIG{__WARN__} = sub { push @warns2, "@_" };
    eval q{ package Foreign; use Moose; has x => (is=>'ro');
            __PACKAGE__->meta->make_immutable; Foreign->new(x=>1); 1 };
}
is( scalar(@warns2), 0, 'unrelated immutable class unaffected' ) or diag "warns: @warns2";

# --- рантайм-применение роли к КЛАССУ ---
{
    package PlainClass;  use Moose;                 # не наследник
    package PlainClassOK; use Moose; extends 'Base1';
}
require Moose::Util;
ok( defined( my $e = do { local $@; eval { Moose::Util::apply_all_roles('PlainClass','RA'); 1 } ? undef : $@ } ),
    'runtime apply to non-subclass class is rejected' );
like( $e, qr/must inherit from Base1/, 'runtime class-apply names base' );
ok( eval { Moose::Util::apply_all_roles('PlainClassOK','RA'); 1 }, 'runtime apply to subclass ok' );

# --- рантайм-применение роли к ОБЪЕКТУ (ToInstance) ---
{
    package PlainObj; use Moose;
}
my $obj = PlainObj->new;
my $ie = do { local $@; eval { Moose::Util::apply_all_roles($obj,'RA'); 1 } ? undef : $@ };
ok( defined $ie, 'runtime apply to non-subclass instance is rejected' );
like( $ie, qr/must inherit from Base1/, 'runtime instance-apply names base' );

done_testing;
