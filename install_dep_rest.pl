#!/usr/bin/perl

# последовательно создает разные тракты и спрашивает а какие зависимости им нужны

# перед тем как запускать этот скрипт надо сначала поставить все необходимые perl-модули запустив скрипт install_dep_perl.pl

use strict;
use FindBin;
use lib $FindBin::Bin."/lib";

use Trakt;
use Path::Tiny;

system ("sudo apt-get update");
system ("sudo apt-get install -y cmake clang git valgrind libdbd-pg-perl screen"); # These packages are minimally needed

# Функция для поиска папок с файлом "trakt.conf"
sub find_folders_with_conf {
    my $dir = shift;
    my @folders_with_conf;

    my @contents = $dir->children;

    # Проверяем каждый элемент на наличие файла "trakt.conf" (только в случае директории)
    foreach my $content (@contents) {
        if ($content->is_dir) {
            my $conf_file = $content->child("trakt.conf");
            if (-e $conf_file) {
                push @folders_with_conf, $content;
            }
        }
    }

    return @folders_with_conf;
}

# ищет перловые программы и модули расположенные в тракте и смотрит какие модули они используют и пытается их поставить...

#my @trakts = ("tests.all.sanitizers", "fuzzing.libpq", "fuzzing.unit-based.type", "fuzzing.unit-based.op.geo", "fuzzing.unit-based.op.ts");  # Все известные тракты
my @trakts = find_folders_with_conf(path('.')); # Тут вызываем новую функцию поиска трактов

my @deps = ();
foreach my $trakt_name (@trakts)
{
  print "**************** $trakt_name *****************\n";

my $command = << 'COMMAND_END';
perl -MCarp::Always -Ilib -e '
use Trakt;
use Path::Tiny;
my $trakt = Trakt->create(name =>"$trakt_name", branch => "std-15");
$trakt->base_dir("/tmp/trakt_debdeps"); # гадить будем в /tmp
print "RESULT:\n";
print join " ", \$trakt->debdeps;
path("/tmp/trakt_debdeps/")->mkpath;
path("/tmp/trakt_debdeps/$trakt_name.deps")->spew(join " ", $trakt->debdeps);
'
COMMAND_END
$command =~ s{\$trakt_name}{$trakt_name}g;

print "EXECUTING: $command";
print `$command`;
die "Что-то пошло не так, с кодом $?\n command=$command" if $?;

my $res = path("/tmp/trakt_debdeps/$trakt_name.deps")->slurp();
push @deps, split /\s/, $res;
}

# ####################### Сканируем новые тракты на предмет зависимостей

my @new_trakts = find_folders_with_conf(path('trakts'));
foreach my $trakt_name (@new_trakts)
{
  $trakt_name = $trakt_name->basename;
  my $work_dir = Path::Tiny->tempdir;

  print "**************** $trakt_name *****************\n";
  my $trakt = Trakt->create(name =>"$trakt_name", branch => "std-17", trakt_path => 'trakts', work_dir => $work_dir );

  my @dep = $trakt->debdeps;
  push @deps, @dep;
}

# руками добавляем пакеты нужные для старого fuzzing.unit-based
push @deps, qw(tmux aha psmisc expect-dev);

my $str = join " ", @deps;
print "######################################################################################\n";
print $str,"\n";
system ("sudo apt-get install -y $str");

personal();

sub personal
{
  my $user = `whoami`;
  chomp $user;
  print "Персонализирую окружение\n";
  if ($user  eq 'nataraj')
  {
    print "Готовлю удобное окружение для пользователя nataraj\n";
    system ("sudo apt-get install vim-pathogen perl-doc libcarp-always-perl");
    system ('git config --global user.email "dhyan@nataraj.su"');
    system ('git config --global user.name "Nikolay Shaplov"');

  } else
  {
    print "Нет персонализорованных настроек для пользователя '$user'\n";
  }
}
