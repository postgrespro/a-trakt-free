#!/usr/bin/perl

# clang'овский геренатор покрытия (как минимум 14й версии) при работе с постгресом при создании .lcov представления генерирует достаточно кривые имена файлов со многими ../ внутри
# Этот скрипт выпрямляет эти кривые пути, сохраняя оригинал с расширение .orig (или .origN если какие-то из .orig-файлов уже существуют) 

use strict;
use Path::Tiny;

my $in = $ARGV[0] || die "Укажите имя lcov файла первым параметром";

$in = path($in);

my $data = $in->slurp();

my $cnt = 0;
my $backup;

while (1)
{
  my $suffix = ".orig";
  $suffix .= "$cnt" if $cnt;
  $backup = path($in.$suffix);
  last if ! $backup->exists;
  $cnt++;
}

$in->move($backup);

my $res = "";

foreach my $line (split /\n/, $data)
{ 
  if ($line =~ /^SF:(.*)$/)
  {
    my $name = path($1);
    $name = $name->realpath();
    $line = "SF:$name";
  }
  $res .= $line."\n";;
}

$in->spew($res);


