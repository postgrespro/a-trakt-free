use strict; use warnings;
use Test::More;
# require, не use: import модуля намеренно croak-ает вне Moose-роли
require_ok('MooseX::RequiresClass');
done_testing;
