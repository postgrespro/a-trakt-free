package Trakt::Step::Reports::LCovClipperTarget;

use Moose::Role;
use Path::Tiny;
use JSON;

use SDL::Ranges;
use SDL::LCovClipper;

around 'core_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;
  $self->$orig(@args);

  print "processing LCov Clipping\n";

  $self->do_clipping();
  $self->do_glueing();
};

# Функция выкусывает из полного покрытия только интересные нам функции
sub do_clipping
{
  my $self = shift;
  my $json = JSON->new->relaxed;

  my $conf_name = $self->step->conf_dir->child('clipper.conf');
  print "Using conf $conf_name\n";
  my $step_conf = $json->decode($conf_name->slurp);

  foreach my $file ($conf_name->parent->children(qr/clipper\.(.*)\.conf/))
  {
    next unless $self->is_range_within_bounds( $file->basename );
    print "Adding extra conf from $file \n";
    my $extra_conf = $json->decode($file->slurp);
    foreach my $key (keys %$extra_conf)
    {
      die "refusing to overwirite config for '$key' target. Failing" if exists $step_conf->{$key};
      $step_conf->{$key} = $extra_conf->{$key}
    }
  }

  my $target_conf = $step_conf->{$self->name};

  die "LCovClipper conf not found for target ".$self->name unless $target_conf;
  my $cache_dir = $self->cache_dir->child('coverage_clipped');
  $cache_dir->remove_tree;
  $cache_dir->mkpath;

  foreach my $key (keys %$target_conf)
  {
    my $in_file = $key;
    my $cov_cache = $self->trakt->step('coverage')->target($self->name)->cache_dir;

    if ($in_file =~ m{^src/})
    {
      $in_file =~ s{^src/}{};
    }
    elsif ($in_file =~ m{^contrib/})
    {
      # для contrib почему-то покрытие появляется по полному пути. Почему -- не понятно. Вот с таким вот извратом обходим это:
      my $path = $self->trakt->step('build')->target('coverage')->cache_dir->child('build_dir/repos/postgrespro')->absolute;
      $in_file = "$path/$in_file";
    }

    $in_file = $cov_cache->child($self->name.".html")->child($in_file.".gcov.html");

    my $out_file = $key;
    $out_file =~ s{/}{_}g;

    $out_file = $cache_dir->child($out_file.".html");

    print "$in_file -> $out_file\n";

    SDL::LCovClipper::clip($in_file, $out_file, $target_conf->{$key});
  }
}

sub is_range_within_bounds {
  my ( $self, $basename ) = @_;

  $basename =~ /^clipper\.(.*)\.conf$/;

  return 0 unless $1;

  # в случае если диапазон не валидный сделает die
  my $ranger = SDL::Ranges->new( prefixes => [ '', 'ent-', 'std-', 'REL_' ] );
  return 0 unless $ranger->match( $1, $self->trakt->convoy->project_version_major );

  return 1;
}


# Склеивает вырезанные из разных исходных файлов покрытие в один html-файл.
sub do_glueing
{
  my $self = shift;

  my $target_name = $self->name;
  my $step_name = $self->step->name;

  print "Запускаем цель '$target_name'\t шага '$step_name'\n";

  my $cache_dir = $self->cache_dir->child('coverage_clipped');
  my @res;
  my ($header_str, $footer_str);
  #$res_file->remove if $res_file->exists;

  foreach my $file (sort $cache_dir->children)
  {
    my $src_str = $file->slurp();
    $header_str = $self->_get_header($src_str) unless $header_str;
    $footer_str = $self->_get_footer($src_str) unless $footer_str;
    my $body = $self->_get_body($src_str);
    @res = (@res, $body);
  }

  @res =("ПОКРЫТИЕ ОТСУТСТВУЕТ!!!!\n") unless @res;

  @res = ("<h2>$target_name</h2>\n", @res);

  $self->cache_dir->mkdir;
  $self->cache_dir->child('coverage_clipped.body')->spew(join("", @res)); # Сохраняем только body для дальнейшего склеивания в колбасу вырезанных покрытий для всего тракта

  $self->res_dir->child('coverage_clipped.html')->spew(join("", $header_str, @res, $footer_str));
}


sub _get_header
{
  my $self = shift;
  my $header_str = shift;
  $header_str =~ s/<body>.*$/<body>/s;
  $header_str =~ s/<title>.*<\/title>/<title>LCOV - profdata.lcov<\/title>/s;
  return $header_str;
}

sub _get_footer
{
  my $self = shift;
  my $footer_str = shift;
  $footer_str =~ s/^.*<\/body>/<\/body>/s;
  return $footer_str;
}

sub _get_body
{
  my $self = shift;
  my $src_str = shift;

  $src_str =~ s/^.*<body>(.*)<\/body>.*/$1/s;
  $src_str =~ /"headerValue">(.*\.c)</;
  my $frag_name = $1;
  $src_str =~ s/<table.*?<\/table.*?<\/table>//s;
  $src_str =~ s/<table width.*?<img.*?<\/table>//s;

  $src_str = "<h3>$frag_name</h3>\n$src_str";
  chomp $src_str;

  return $src_str;
}


1;
