package Trakt::Conf2;

use Moose;

use JSON;
use Path::Tiny;

#has "cert" =>(is =>'rw', lazy => 1, builder => '_read_cert_conf');
#has "_cert_conf_file" => (is => 'rw', isa => 'Path::Tiny');
has 'trakt' => (is => 'rw', isa => 'Trakt', weak_ref => 1);


around BUILDARGS => sub {
    my ($orig, $class, @args) = @_;
    my $res = $class->$orig(@args);

    #    $res->{_cert_conf_file} = path($res->{cert_conf}) if $res->{cert_conf};

    #    # delete $res->{cert_conf}; # FIXME потом зачищать чтобы не мешался

    return $res;
};

#sub _read_cert_conf
#{
#  my $self = shift;
#  my $json = JSON->new->relaxed;
#  return $json->decode($self->{_cert_conf_file}->slurp);
#}

1;
