package Trakt::Cert;

# Абстракция описывающая "сертификацию" или "ИК" в рамках которого происходит
# запуск тракта.

use Moose;

use JSON;
use Path::Tiny;


has "conf" =>(is =>'rw', lazy => 1, builder => '_read_conf');
has "conf_file" => (is => 'rw');

has "name" =>(is => 'ro', lazy => 1, default => sub {shift->conf->{name}});
has "is_test" =>(is => 'ro', lazy => 1, default => sub {shift->conf->{is_test}});

sub _read_conf
{
  my $self = shift;
  my $json = JSON->new->relaxed;
  my $file = path($self->conf_file); # FIXME переделать через coerse
  my $res =  $json->decode($file->slurp);

  return $res;
}

1;
