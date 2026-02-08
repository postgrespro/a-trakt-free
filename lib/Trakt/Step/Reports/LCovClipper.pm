package Trakt::Step::Reports::LCovClipper;

use strict;

use Moose::Role;
use Path::Tiny;

# Метод augment вызывается из родительского метода при помощи вызова inner()
around 'after_run' => sub
{
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  my $res = '';
  my ($header, $footer);
  my $trakt_name = $self->trakt->name;
  my $trakt_branch = $self->trakt->branch;

  foreach my $target_name ($self->targets)
  {
    my $target = $self->target($target_name);

    if (! $header)
    {
       my $html = $target->res_dir->child('coverage_clipped.html')->slurp();
       $header = $target->_get_header($html);
       $footer = $target->_get_footer($html);
    }
    my $body = $target->cache_dir->child('coverage_clipped.body')->slurp();
    $body =~ s/<br>\s*<br>//sg;   # FIXME: Перенести эти две строки в _get_body?
    $body =~ s/<tr>\s*<td><br><\/td>\s*<\/tr>//sg;
    $res .= $body;
    $res ="\n$res"; # FIXME Для обратной совместимости. Позже -- убрать, оно делает не красиво
  }
  $res = "\n<h1>$trakt_name, $trakt_branch</h1>".$res;

  my $total_res_file = $self->trakt->res_dir->child('coverage_clipped_total.html');
  $total_res_file->spew($header.$res.$footer);

  $self->$orig(@args);
};

1;

