package Trakt::Step::SampleStorage::Put;

use Moose;
extends 'Trakt::Step';

around 'debdeps' => sub {
    my $orig = shift;
    my $self = shift;

    return ($self->$orig(@_), qw(libdbd-pg-perl));
};


1;

package Trakt::Step::SampleStorage::Put::Target;

use Moose;
extends 'Trakt::Target';

use Samples;

around 'core_run' => sub {
  my $orig = shift;
  my $self = shift;
  my @args = @_;

  my $trakt_name = $self->trakt->full_name;
  my $target_name = $self->name;
  my $step_name = $self->step->name;

  my $res_dir = $self->res_dir;
  my $sample_dir = $res_dir->child('samples');

  my @sample_names = $sample_dir->children;

  my $cert_conf = $self->trakt->conf->{cert};
  die "Cert conf have not been loaded, did you forgot to specify 'cert_conf' while trakt init?" if ref $cert_conf ne 'HASH';

  if ($cert_conf->{is_test})
  {
    print "Test Run Detected, no result to be stored\nSkipping sample_put";
    return 1;
  }

  my $cert_name = $cert_conf->{name};
  my $storage_conf = $self->step->conf;

  my @knonw_certs = Samples::list_certs(conf => $storage_conf);
  my $found = 0;
  foreach (@knonw_certs)
  {
    if ($_ eq $cert_name)
    {
      $found = 1;
      last;
    }
  }
  die "Certification '$cert_name' is not registered in sample storage. Create it and try again" unless $found;

  my $count = Samples::upsert_samples(conf => $storage_conf, cert => $cert_name, trakt => $trakt_name, target=> $self->name, branch=> $self->trakt->conf->{branch}, samples => \@sample_names);

  return ($self->$orig(@args));
};


1;
