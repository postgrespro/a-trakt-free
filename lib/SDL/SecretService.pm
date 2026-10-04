package SDL::SecretService;

use strict;
use Moose;
use JSON;
use Cwd;
use Path::Tiny qw( path );

# Каталог до папки secrets где лежат файлы с секретами
# по считаем что они где-то в корне тракта.
has dir => ( is => 'rw', default => sub { path(__FILE__)->parent(3)->child('secrets')->realpath } );  #__FILE__ путь к текущему модулю

has secrets => (
    is  => 'ro',
    isa => 'HashRef',
    default => sub {
        {
#            project_name => 'project-deploy-token.conf',
        }
    }
);

sub retrieve_credentials {
    my ( $self, $codename ) = @_;

    my $data = $self->get_secrets( $codename );
    if ( ref $data eq 'HASH' && $data->{token} ) {
        return split /:/, $data->{token};
    }
    return;
}

sub get_secrets {
    my ( $self, $codename ) = @_;

    die 'must name of codename in args' unless $codename;
    return unless $self->secrets->{$codename};

    return $self->_convert_from_json( $self->secrets->{$codename} );
}

sub _convert_from_json {
    my ( $self, $file ) = @_;

    my $json        = JSON->new->relaxed;
    my $secret_data = $json->decode( $self->_get_data_from_file( $file ) );
    
    return {
        token   => $secret_data->{login} . ':' . $secret_data->{password},
        project => $secret_data->{project}, 
    }
}

sub _get_data_from_file {
    my ( $self, $filename ) = @_;
    return path( $self->dir .'/'. $filename )->slurp;
}

1;
