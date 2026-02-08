#!/usr/bin/perl

use strict;

BEGIN {
# Ставим зависимости пока еще ничего не началось
system ("sudo apt-get update");
system ("sudo apt-get install -y libpath-tiny-perl libfile-grep-perl");
}

use Path::Tiny;
use File::Grep;

# ищет перловые программы и модули расположенные в тракте и смотрит какие модули они используют и пытается их поставить...
my @trakts = (get_trakt_dirs(path('.')), get_trakt_dirs(path('trakts'))); # Ищем существующие тракты
my @raw_list = ();
my @deb_names=('libcarp-always-perl');


my @perl_files = ();

foreach my $trakt (@trakts, ".") # "." Это чтобы искать в lib из корня проекта
{
  push @perl_files, recursive_file_find("$trakt/lib", qr/\.pm\z/) if -e "$trakt/lib";
  push @perl_files, recursive_file_find("$trakt/bin", qr/\.pl\z/) if -e "$trakt/bin";
}
push @perl_files, recursive_file_find("./t", qr/\.t\z/);
push @perl_files, recursive_file_find("./utils", qr/\.pl\z/);
push @perl_files, recursive_file_find(".", qr/\.pl\z/, 0);  # ищем с глубиной 0, т.е. только в самой директории

my @modules_raw = ();

foreach my $ress (File::Grep::fgrep {/^use/} @perl_files)
{
  foreach my $n (values %{$ress->{matches}})
	{
		chomp $n;
    $n =~ s/^use\s+//;
    $n =~ s/(^\S+)\s.*$/$1/;   # Убираем все что после пробела. Например список экспортируемых функций
    $n =~ s/;$//; #удаляем финальную точку с запятой
    next if $n=~/^\d+\.\d+$/;          # игнорируем юзы вида use 5.006;
    next if $n=~/^lib|^strict|^warnings|^parent|^utf8/; # пропускаем прагмы
    push @modules_raw, $n;
	}
}

foreach my $ress (File::Grep::fgrep {/^with/} @perl_files)
{
  foreach my $n (values %{$ress->{matches}})
	{
		chomp $n;
    $n =~ s/^with\s+//;
    $n =~ s/;$//; #удаляем финальную точку с запятой
    $n =~ s/\s|"|'//g;
    my @l = split ',',$n;
		push @modules_raw, @l
	}
}

my %known = ();
my @perl_names = ();
foreach my $n (@modules_raw)
{
  next if $n=~/^SDL::|^Local::|^Trakt/; # Внутрение пространства имен
  next if $n=~/^Samples|^TmuxPaner::RootPane/; # Другие модули, которые наши
  next if $n=~/^File::Size/; # Модули которые не наши, но которые мы тащим с собой в дистрибутиве
  next if $n=~/^Moose::Role/; # Иные модули которые не надо ставить (например потому что они часть уже поставленного пакета с модулями)
  next if $n=~/^Test::Role/; # Необходимо для тестов и не нужно ставить

  next if $known{$n};
  $known{$n} = 1;
  push @perl_names, $n;
}

foreach my $n (@perl_names)
{
  eval("use $n;"); # проверяем, не установлен ли этот модуль уже...
  next unless $@;
  $n = lc($n);
  $n =~ s/::/-/g;
  $n = "lib$n-perl";
  push @deb_names, $n;
}

foreach my $pkg ( @deb_names ) {
  system("sudo apt-get install -y $pkg");
}

# Функция для поиска папок с файлом "trakt.conf"
sub get_trakt_dirs
{
  my $path = shift;
  my @res = ();
  my @l = recursive_file_find($path,qr/^trakt\.conf\z/, 1); # Ищем директории в которых есть trakt.conf не глубже первого уровня
  foreach my $file (@l)
  {
    push @res, path($file)->parent;
  }
  return @res;
}

sub recursive_file_find
{
  my $dir = path(shift);
  my $mask = shift // qr/.*/;
  my $depth = shift // -1;
  my @res = ();
  if ($depth !=0)
  {
    foreach my $file ($dir->children)
    {
      next unless $file->is_dir;
      push @res, recursive_file_find($file, $mask, $depth - 1)
    }
  }
  foreach my $file ($dir->children($mask))
  {
    next if $file->is_dir;
    push @res, "$file";
  }
  return @res;
}

