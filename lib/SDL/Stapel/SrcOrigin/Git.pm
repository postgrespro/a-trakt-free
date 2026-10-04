package SDL::Stapel::SrcOrigin::Git;

use Moose;
use Path::Tiny;
use URI::Escape;

# Ниже лежащий use нужен только для того, чтобы поставилась нужная зависимость. Нужный нам URI::Escape часть этого пакет
# Когда сделаем более лучшую систему установки зависимостей, этот use можно будет удалить
use URI;

extends 'SDL::Stapel::SrcOrigin';

sub known_gits
{
  # return
  # { repo_code_name => {https => "https://git.postgresql.org/git/postgresql.git",
  #                     git => git://git.postgresql.org/git/postgresql.git,
  #                    # ssh => '',
  #                      need_auth => 0,
  #                    # token_name => 'non-free-project/non-free-repo' } # Имя токена для авторизации из хранилища секретов
  # };
}

sub git_spec_from_release_spec
{
  # my $self = shift;
  # my $release_spec = shift;
  #
  # Реализовать выбор одного из known_gits на основании release_spec. Добавить code_name;
}

sub _sklad
{
  my $self = shift;
  my $release_spec = shift;
  my $res = $self->helling->sklad->child('_git')->child($release_spec->git_repo_codename);

  return  $res;
}

sub get_sources
{
  my $self = shift;
  my $release_spec = shift;
  my $dst_dir = shift;

  my $git_spec = $self->git_spec_from_release_spec($release_spec);
  my $git_url = $git_spec->{https} // $git_spec->{git} // $git_spec->{ssh};

  die "Репозиторий $git_url почему-то не имеет кодового имени" unless $git_spec->{code_name};
  my $work_dir = $self->helling->sklad->child('_git')->child($git_spec->{code_name});

  my $revision = $release_spec->revision();

  local %ENV = %ENV; # Создаем локальную версию переменных окружения. Может ниже, если понадобится авторизация передадим через нее токен.

  if ($git_spec->{need_auth})
  {
    my ( $login, $password ) = $self->helling->secret_service->retrieve_credentials( $git_spec->{token_name} );

    $git_url =~ s{^https://}{https://\$GIT_AUTH_TOKEN\@};
    $ENV{GIT_AUTH_TOKEN} = "$login:".uri_escape($password);
  }

  if(! $work_dir->child('.git')->exists)
  {
    $self->helling->run_command('git_get_src',"git clone $git_url $work_dir");
    $self->helling->run_command('git_get_src', "git -C $work_dir checkout $revision");
  } else
  {
    $self->helling->run_command('git_get_src', "git -C $work_dir fetch --all");
    $self->helling->run_command('git_get_src', "git -C $work_dir checkout $revision");
    my $cur_branch = `git -C $work_dir  branch --show-current`;
    $self->helling->run_command('git_get_src', "git -C $work_dir pull") if $cur_branch; # Догоняемся до головы ветки, но только если это векта.
  }
  $dst_dir = path($dst_dir) unless ref($dst_dir);
  $dst_dir->remove_tree({safe => 0}) if $dst_dir->exists;
  $dst_dir->mkpath;

  $self->helling->run_command('git_get_src', "cp -R $work_dir/. $dst_dir");
}

1;
