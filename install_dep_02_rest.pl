#!/usr/bin/perl

# последовательно создает разные тракты из каталога `trakts` и спрашивает а какие зависимости им нужны
# перед тем как запускать этот скрипт надо сначала поставить все необходимые perl-модули запустив скрипт install_dep_01_perl.pl

use strict;
use FindBin;
use lib $FindBin::Bin."/lib";

use Trakt;
use Path::Tiny;

system ("sudo apt-get update");
system ("sudo apt-get install -y cmake clang git valgrind libdbd-pg-perl screen");

ensure_locales('ru_RU.CP1251', 'en_US.UTF-8');

my @deps;
my @trakts = find_folders_with_conf(path('trakts'));
foreach my $trakt_name (@trakts)
{
  $trakt_name = $trakt_name->basename;

  my $work_dir = Path::Tiny->tempdir;
  my $res_file = Path::Tiny->tempfile;
  print "**************** $trakt_name *****************\n";

  # Алабамский тракт не подразумивает возможнсти одновременного существования несольких трактов в одном пространстве
  # Так как потенциально могут пересекаться разные одноименные классы. Например Local::Build для каждого тракта. Поэтому
  # получаем список зависимостей отдельными запусками
  my $command = <<END;
  use strict;
  use lib "$FindBin::Bin/lib";
  use Trakt;
  use Path::Tiny;

  my \$trakt = Trakt->create(name =>"$trakt_name", branch => "std-17", trakt_path => "trakts", work_dir => "$work_dir" );

  my \@dep = \$trakt->debdeps;
  path("$res_file")->spew(join("\\n",\@dep));
END

  $command =~ tr/\n/ /;
  #  print "--------------- echo '$command' | perl -----------\n";
  system("echo '$command' | perl");
  push @deps, split(/\n/, $res_file->slurp());
}

my $str = join " ", sort uniq(@deps);
print "######################################################################################\n";
print $str,"\n";
system ("sudo apt-get install -y $str");

personal();

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

sub uniq {
  my %seen;
  return grep { !$seen{$_}++ } @_
}

# функция для определения какие у нас есть локали в системе и добавление не достающих
sub ensure_locales {
    my @wanted = @_;
    return unless @wanted;

    my %locale_info = (
        'en_US.UTF-8' => {
            la      => 'en_US.utf8',   # как она выглядит в locale -a
            charset => 'UTF-8',        # что пишем во 2-й колонке /etc/locale.gen
        },
        'ru_RU.CP1251' => {
            la      => 'ru_RU.cp1251',
            charset => 'CP1251',
        },
    );

    # что уже есть в locale -a
    my %have;
    open my $fh, "-|", "locale -a" or die "cannot run locale -a: $!";
    while (<$fh>) {
        chomp;
        $have{$_} = 1;
    }
    close $fh;

    my @missing;
    for my $loc (@wanted) {
        my $info = $locale_info{$loc} or die "no locale_info for $loc\n";
        my $la   = $info->{la};
        push @missing, $loc unless $have{$la};
    }
    return unless @missing;

    system("which locale-gen >/dev/null 2>&1") == 0
        or system("sudo apt-get install -y locales") == 0
        or die "locale-gen not found and cannot install locales\n";

    my $gen_file = "/etc/locale.gen";
    -f $gen_file or die "$gen_file not found\n";

    my $backup = "$gen_file.bak";
    system("sudo cp '$gen_file' '$backup'") == 0
        or warn "cannot backup $gen_file\n";

    open my $in, "<", $gen_file or die "cannot read $gen_file: $!";
    my @lines = <$in>;
    close $in;

    for my $loc (@missing) {
        my $info    = $locale_info{$loc};
        my $charset = $info->{charset};

        my $found = 0;
        for my $l (@lines) {
            if ($l =~ /^#\s*\Q$loc\E\b/) {   # раскомментировать
                $l =~ s/^#\s*//;
                $found = 1;
                last;
            }
            if ($l =~ /^\Q$loc\E\b/) {       # уже активно
                $found = 1;
                last;
            }
        }

        next if $found;

        push @lines, "$loc $charset\n";
    }

    open my $out, "|-", "sudo tee $gen_file >/dev/null"
        or die "cannot open sudo tee: $!";
    print {$out} @lines;
    close $out or die "cannot write $gen_file\n";

    my $list = join " ", @missing;
    system("sudo locale-gen $list") == 0
        or die "locale-gen failed for: $list\n";

    return;
}
