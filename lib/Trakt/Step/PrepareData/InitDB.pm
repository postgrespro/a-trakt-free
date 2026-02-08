package Trakt::Step::PrepareData::InitDB;

use Moose::Role;
use File::Copy::Recursive qw(rcopy);


sub pgdata
{
  my $self = shift;
  return $self->exchange_dir->child('pgdata')->absolute;
}

sub targets
{
 return ();
}

sub initdb_extra_options
{
  return "";
}

sub pgbin
{
  my $self = shift;
  my $name = shift;
  return $self->trakt->convoy->bin_dir($self->trakt->convoy->default_build)->child($name);
}


# Теперь initdb делается в рамках системы сборки, чтобы не переписывать сразу всё, мы эти данные посто оттуда скопируем.
# FIXME этот класс пока сохранен для обратной совместимости. По хорошему его надо будет в будущем просто сократить.
after 'do_prepare_data' => sub {
  my $self = shift;

  my $pgdata = $self->pgdata;

  my $stapel = $self->trakt->step('build')->target($self->trakt->convoy->default_build)->stapel;

  $pgdata->remove_tree( { safe => 0 } );
  $pgdata->mkpath;

  rcopy($stapel->context_data_dir, $pgdata ) or die $!;
};

1;
