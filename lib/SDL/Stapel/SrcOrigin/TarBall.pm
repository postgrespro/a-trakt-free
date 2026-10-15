package SDL::Stapel::SrcOrigin::TarBall;

use Moose;
use URI::Escape;
use Path::Tiny;
use File::Copy::Recursive qw(rcopy);

extends 'SDL::Stapel::SrcOrigin';

has 'file' => (is => 'rw', isa => 'Str', required => 1);

sub _sklad
{
  my $self = shift;
  my $release_spec = shift;
  my $res = $self->helling->sklad->child('_git')->child($release_spec->git_repo_codename);

  return  $res;
}


# Вообще это должна быть достаточно универсалная функция, но пока она расчитана только на дистрибутив postgrespro
sub get_sources
{
  my $self = shift;
  my $release_spec = shift;
  my $dst_dir = shift;

  $dst_dir = path($dst_dir) unless ref($dst_dir);
  $dst_dir->remove_tree({safe => 0}) if $dst_dir->exists;
  $dst_dir->mkpath;

  my $tmp_dir = Path::Tiny->tempdir;

  $self->helling->run_command('git_get_src', "tar -xvf ".$self->file." -C $tmp_dir");

  my @subdirs = $tmp_dir->children();
  die "Архив '".$self->file."' содержит более одной директории в корне. Так быть не должно " unless @subdirs == 1;
  die "В архиве '".$self->file."' не директория" unless $subdirs[0]->is_dir;

  my $work_dir = $subdirs[0];
  $self->helling->run_command('tarball_copy_src', "cp -R $work_dir/. $dst_dir");
}

1;
