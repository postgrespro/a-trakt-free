use strict; use warnings;
use Test::More;

{
    package Base1; use Moose; __PACKAGE__->meta->make_immutable;
    package Base2; use Moose; __PACKAGE__->meta->make_immutable;
    package RoleNeedsBase1;
    use Moose::Role; use MooseX::RequiresClass;
    requires_class 'Base1';
    requires 'helling';                 # штатный requires должен работать рядом
    sub configure { 'configured' }
}

# наследник + требуемый метод: собирается и работает
{
    package Good; use Moose; extends 'Base1'; sub helling {1}
    with 'RoleNeedsBase1'; __PACKAGE__->meta->make_immutable;
}
is( Good->new->configure, 'configured', 'subclass consumes role, method available' );

# не-наследник: отказ на композиции
my $ok = eval q{ package Bad; use Moose; sub helling {1} with 'RoleNeedsBase1'; 1 };
ok( !$ok, 'non-subclass fails at composition' );
like( $@, qr/must inherit from Base1/, 'error names the required base' );

# штатный requires жив: наследник без helling падает по requires
my $ok2 = eval q{ package NoMethod; use Moose; extends 'Base1'; with 'RoleNeedsBase1'; 1 };
ok( !$ok2, 'native requires still enforced' );
like( $@, qr/requires the method 'helling'/, 'native requires error' );

# несколько базовых классов
{
    package RoleNeedsBoth; use Moose::Role; use MooseX::RequiresClass;
    requires_class 'Base1', 'Base2';
}
ok(  eval q{ package B12; use Moose; extends 'Base1','Base2'; with 'RoleNeedsBoth'; 1 }, 'both bases: ok' );
ok( !eval q{ package B1o; use Moose; extends 'Base1'; with 'RoleNeedsBoth'; 1 }, 'missing one base: rejected' );
like( $@, qr/must inherit from Base2/, 'names the missing base' );

# пустой requires_class -> ошибка
ok( !eval q{ package REmpty; use Moose::Role; use MooseX::RequiresClass; requires_class(); 1 },
    'requires_class with no args dies' );
like( $@, qr/at least one class/, 'empty requires_class error' );

done_testing;
