package Trakt::Step::SampleStorage::Get;

use Moose;
extends 'Trakt::Step';

around 'debdeps' => sub {
    my $orig = shift;
    my $self = shift;

    return ($self->$orig(@_), qw(libdbd-pg-perl));
};


1;

package Trakt::Step::SampleStorage::Get::Target;

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

  my $conf = $self->step->conf;
  my $cert_conf = $self->trakt->conf->{cert} || {};


  $self->run_command("cleanup", "rm -rf ".$self->exchange_dir);
  $self->exchange_dir->mkpath;

  my $branch_name =  $self->trakt->conf->{branch};

  print "Looking for previous '$target_name' samples for '$branch_name' branch\n";
  my $res = Samples::get_samples(conf => $conf, trakt => $trakt_name, target=> $target_name, path => $self->exchange_dir, branch => $branch_name, current_cert => $cert_conf->{name});
  if ($res->{count} ==0)
  {
    print "Trying to find just any branch with samples for '$target_name' target\n";
    $res = Samples::get_samples(conf => $conf, trakt => $self->trakt->name, target=> $target_name, path => $self->exchange_dir, current_branch => $branch_name, current_cert => $cert_conf->{name} );
    die "No samples found for target ".$self->name." of trakt ",$self->trakt->name if $res->{count} == 0;

    print "Got ".$res->{count}." samples!\n";
  }

  # use Data::Dumper;
  # die Dumper $res;
  # $self->stash_report_var("test", 123);

  $self->sklad->samples->add('',$self->exchange_dir->child('*'));

  return ($self->$orig(@args));
};


1;
