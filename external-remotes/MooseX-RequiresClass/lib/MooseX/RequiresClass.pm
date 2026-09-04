package MooseX::RequiresClass;
use strict;
use warnings;
use Moose::Util ();
use Carp ();

our $VERSION = '0.05';

# Единственный триггер: обёртка Moose::Meta::Role::Application::ToClass::apply.
# Ловит ЛЮБОЕ применение роли к классу (одиночный/композитный/матрёшечный with,
# и рантайм apply_all_roles) в момент композиции. Подклассы проверять не надо:
# isa наследуется, потому если родитель удовлетворил требование, потомок тоже.
# Требует штатного порядка: extends раньше with.

{
    package MooseX::RequiresClass::Aggregator;
    use Moose::Role;
    use Carp ();
    sub _moosex_requiresclass_total_claims { () }
    sub _moosex_requiresclass_check {
        my $self  = shift;
        my $class = ref($self) || $self;
        for my $base ($class->_moosex_requiresclass_total_claims) {
            Carp::confess(
                "$class must inherit from $base to consume a MooseX::RequiresClass role"
            ) unless $class->isa($base);
        }
        return;
    }
}

my $APPLY_HOOKED = 0;
my %OPTED_OUT;   # { consumer_class => 1 } — классы с явным -no_baseclass_checks
sub _install_apply_hook {
    return if $APPLY_HOOKED;
    $APPLY_HOOKED = 1;
    no warnings 'redefine';
    my $orig = \&Moose::Meta::Role::Application::ToClass::apply;
    *Moose::Meta::Role::Application::ToClass::apply = sub {
        my ($self, $role, $consumer, @rest) = @_;
        my $ret  = $self->$orig($role, $consumer, @rest);
        my $name = $consumer->name;
        return $ret unless $name->can('_moosex_requiresclass_check');
        # Per-class opt-out: -no_baseclass_checks в любом with помечает КЛАСС
        # как не-проверяемый, и с этого момента проверка его пропускает целиком
        # (без утечки per-apply-семантики).
        for my $arg (@rest) {
            $OPTED_OUT{$name} = 1 if ref $arg eq 'HASH' && $arg->{'-no_baseclass_checks'};
        }
        return $ret if $OPTED_OUT{$name};
        $name->_moosex_requiresclass_check;
        return $ret;
    };
}

sub _requires_class {
    my ($role_name, @classes) = @_;
    Carp::croak('requires_class requires at least one class name') unless @classes;
    my $meta = Moose::Util::find_meta($role_name);
    $meta->add_around_method_modifier(
        '_moosex_requiresclass_total_claims',
        sub { my $orig = shift; ($orig->(@_), @classes) },
    );
    return;
}

sub import {
    my $class  = shift;
    my $caller = caller;
    my $meta   = Moose::Util::find_meta($caller);
    Carp::croak(
        "MooseX::RequiresClass may only be used inside a Moose role "
        . "(did you forget `use Moose::Role;` first?)"
    ) unless $meta && $meta->isa('Moose::Meta::Role');
    Moose::Util::apply_all_roles($meta, 'MooseX::RequiresClass::Aggregator');
    { no strict 'refs'; *{"${caller}::requires_class"} = sub { _requires_class($caller, @_) }; }
    _install_apply_hook();
    return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MooseX::RequiresClass - require that a role's consumer inherits from a given class

=head1 SYNOPSIS

    package My::Role;
    use Moose::Role;
    use MooseX::RequiresClass;

    requires_class 'My::Base';       # consumers must inherit from My::Base

    sub some_method { ... }

    package My::Class;
    use Moose;
    extends 'My::Base';              # note: extends before with
    with 'My::Role';                 # ok

    package Bad::Class;
    use Moose;
    with 'My::Role';                 # dies: Bad::Class must inherit from My::Base

=head1 DESCRIPTION

Moose's built-in C<requires> lets a role demand that its consumer implement
certain B<methods>. It cannot demand that the consumer be a subclass of a
particular B<class>. C<MooseX::RequiresClass> adds that: a role declares
C<requires_class 'Some::Base'>, and any class consuming that role is checked
with C<< $consumer->isa('Some::Base') >> at composition time.

Enforcement happens when the role is composed into a class, so a violation is
reported early — while the consuming class is being defined — rather than at
object construction. Coverage includes single consumption (C<with 'Role'>),
combined consumption (C<with 'A', 'B'>), nested consumption (a role that
consumes a C<requires_class> role, then applied to a class), and roles applied
to a class or instance at runtime.

=head1 EXPORTS

=head2 requires_class

    requires_class 'Base::Class';
    requires_class 'Base::One', 'Base::Two';

Exported into the consuming role. Declares one or more classes that the role's
eventual consumer must inherit from. Multiple calls accumulate. Calling it with
no arguments is an error.

=head1 OPTING OUT

A consuming class may waive the requirement explicitly:

    package My::Class;
    use Moose;
    with 'My::Role' => { -no_baseclass_checks => 1 };

The dashed key follows the convention of Moose's own C<-alias> / C<-excludes>
application options. See L</CAVEATS> for its per-class semantics.

=head1 CAVEATS

=over 4

=item * C<extends> must come before C<with>

The check runs while the role is composed into the class (during C<with>) and
reads the class's inheritance as it stands at that moment. Use the conventional
Moose ordering — C<extends> before C<with>. If C<with> runs first, the check
sees the base class as not-yet-established and reports a spurious failure.

=item * A core Moose method is wrapped globally

On first use this module wraps
C<Moose::Meta::Role::Application::ToClass::apply> for the whole process. The
wrapper is guarded: for any class that never consumed a C<requires_class> role
it merely delegates to the original, so unrelated roles and classes are
unaffected in behaviour (they do pass through one extra method call at
composition time). The wrapper preserves and calls the previous implementation,
so it composes with an earlier wrapper; but as with any global patch, a later
module that replaces the same method without preserving it would clobber this
one.

=item * C<-no_baseclass_checks> opts out the whole class

The opt-out is per-class, not per-role: passing
C<< with 'SomeRole' =E<gt> { -no_baseclass_checks =E<gt> 1 } >> marks the
consuming class as exempt from B<all> base-class checks from that point on, not
only for that one role. Because checks fire per composition, place the flag on
the first (or only) requiring C<with>: a flag on a later C<with> will not
retroactively suppress a check that an earlier requiring C<with> already
performed.

=back

=head1 SEE ALSO

L<Moose>, L<Moose::Role>, L<Moose::Manual::Roles>.

=head1 AUTHOR

Nataraj

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.

=cut
