package SDL::Stapel::PatchSet;

use Moose::Role;

has patches => (is => 'rw', builder => 'patches_defaults');
has dirs  => (is => 'rw', builder => 'dirs_defaults'); # Директории с файлами которые должны быть записаны поверх


sub patches_defaults
{
  return [];
}

sub dirs_defaults
{
  return [];
}



1;
