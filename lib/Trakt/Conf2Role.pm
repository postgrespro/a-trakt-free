package Trakt::Conf2Role;

# Роль обеспечивающая функционал работы с конфигами для тракта. Сейчас в ней только новые вещи, легаси из Trakt::Conf наверное когда-то надо будет
# тоже перенести сюда.

use Moose::Role;
use JSON;
use Path::Tiny;
use TOML::Tiny qw( from_toml );

has "forced_conf" =>(is =>'rw', lazy => 1, builder => 'read_forced_conf');

sub forced_conf_name
{
    my $self = shift;
    my $trakt_name = $self->name;

    my $res = $self->work_dir->child("$trakt_name.toml");
    return $res;
}


sub read_forced_conf
{
    my $self = shift;

    my $name = $self->forced_conf_name;

    return {} unless $name->exists;

    return from_toml( $name->slurp_utf8 );
}

1;
