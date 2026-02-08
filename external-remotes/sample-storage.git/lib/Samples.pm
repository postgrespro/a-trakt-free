package Samples;
use strict;
#use warnings FATAL => 'all';

use DBD::Pg;
use Path::Tiny;
use JSON;
use File::Basename;


our $our_dbh = undef;

sub _dbh {
    my $conf_name = shift;

    return $our_dbh if $our_dbh;

    my $conf;

    if (ref ($conf_name) eq 'HASH') # Передали не имя, а сам конфиг
    {
       $conf=$conf_name;
    } else
    {
      eval {
          $conf = JSON::decode_json(path($conf_name)->slurp);
      };
      if ($@) {
          die "Your JSON is invalid: $@\n";
      }
    }
    my $driver   = $conf->{'database'};
    my $dbname   = $conf->{'dbname'};
    my $host     = $conf->{'host'};
    my $user     = $conf->{'user'};
    my $password = $conf->{'password'};

    my $dsn = "dbi:$driver:dbname=$dbname;host=$host";

    my $dbh = DBI->connect($dsn, $user, $password, {
        PrintError       => 0,
        RaiseError       => 1,
        AutoCommit       => 1,
        FetchHashKeyName => 'NAME_lc',
    });
    $our_dbh = $dbh;
    return ($dbh);
}


sub put_sample {
    my $conf_name = shift;
    my $dbh = _dbh($conf_name);
    my ($path_to_sample, $project, $certification, $branch, $trakt_name, $target, $name) = @_;

    die "\nNot enough arguments\n" unless defined $name;

    my $sql = "INSERT INTO samples(project_name, certification_name, branch_name, trakt_name, target_name, sample_name, sample_file) VALUES (?, ?, ?, ?, ?, ?, pg_read_binary_file(?))";

    my $sth = $dbh->prepare($sql);
    $sth->execute($project, $certification, $branch, $trakt_name, $target, $name, $path_to_sample);

    print "\nInsertion successful\n";
}

sub get_sample {
        my $conf_name = shift;
        my $dbh = _dbh($conf_name);
        my ($project, $certification, $branch, $trakt_name, $target, $name, $path) = @_;

        die "\nNot enough arguments\n" unless defined $path;

        my $sql = "SELECT samples.project_name, samples.certification_name, samples.certification_date, samples.branch_name, samples.trakt_name, samples.target_name, samples.sample_name, samples.created_at, samples.sample_file FROM samples WHERE project_name=? AND certification_name=? AND branch_name=? AND trakt_name=? AND target_name=? AND sample_name=?";

        my $sth = $dbh->prepare($sql);
        $sth->execute($project, $certification, $branch, $trakt_name, $target, $name);

        while (my @row = $sth->fetchrow_array) {
            print "\nProject name: $row[0]\nCertification name: $row[1]\nCertification_date: $row[2]\nBranch name: $row[3]\nTrakt name: $row[4]\nTarget name: $row[5]\nSample name: $row[6]\nCreated at: $row[7]\n";
            open(my $fh, ">$path/$row[6]");
            print $fh $row[8];
            close($fh) || die "\nCan't close the file $row[6]";
        }
}

# У нас пока один проект
sub guess_project
{
  print STDERR "Guessing project name = postgrespro\n";
  return "postgrespro";
}

sub guess_cert
{
    my %opt = @_;
    my $dbh = _dbh($opt{conf});

    # Эта конструкия позволяет выбирать не среди всех сертификаций, а только среди тех, что раньше заданной
    # Это позволит не использовать при перефаззинге в рамках текущей сертификации результаты от предыдущего, возможно неудачного запуска

    my $res;

    if ($opt{branch})
    {

      my $sql = "SELECT DISTINCT s.certification_name, c.certification_date FROM samples as s, certifications as c WHERE
                        c.certification_name = s.certification_name AND s.project_name=? AND s.branch_name=? AND s.trakt_name=? AND s.target_name=? ORDER BY c.certification_date DESC";

      my $sth = $dbh->prepare($sql);
      $sth->execute($opt{project}, $opt{branch}, $opt{trakt}, $opt{target});

      ($res) = $sth->fetchrow_array;
      # Текущая сертификация нас не устроит, мы не можем использовать сэмплы от самих себя
      if ($opt{current_cert} && $opt{current_cert} eq $res)
      {
        # берем следующую. Там уже должно что-то отличаться
        ($res) = $sth->fetchrow_array;
      }
    } else
    {
      my $sql = "SELECT DISTINCT s.certification_name, s.branch_name ,c.certification_date FROM samples as s, certifications as c WHERE
                        c.certification_name = s.certification_name AND s.project_name=? AND s.trakt_name=? AND s.target_name=? ORDER BY c.certification_date DESC";

      my $sth = $dbh->prepare($sql);
      $sth->execute($opt{project}, $opt{trakt}, $opt{target});
      my $branch;
      ($res, $branch) = $sth->fetchrow_array;
      # Текущая сертификация нас не устроит, мы не можем использовать сэмплы от самих себя
      if ($opt{current_cert} && $opt{current_branch} && $opt{current_cert} eq $res && $opt{current_branch} eq $branch)
      {
        # берем следующую. Там уже должно что-то отличаться
        ($res) = $sth->fetchrow_array;
      }
    }
    print "Guessing certification = $res\n" if defined $res;
    print "Guessing certification: NOT POSSIBLE!\n" unless defined $res;
    return $res;
}

sub guess_branch
{
    my %opt = @_;
    my $dbh = _dbh($opt{conf});

    my $res;

    # Ищем ветку заданной сертификации в которой есть какие-то сэмплы, берем самую свежую. Если это текущая ветка и current_cert, то берем следующую за ней.
    my $sql = "SELECT DISTINCT s.branch_name, c.certification_name, c.certification_date FROM samples as s, certifications as c WHERE
                    c.certification_name = s.certification_name AND s.project_name=? AND c.certification_name=? AND s.trakt_name=?  AND s.target_name=? ORDER BY c.certification_date";

    my $sth = $dbh->prepare($sql);
    $sth->execute($opt{project}, $opt{cert}, $opt{trakt}, $opt{target});
    ($res) = $sth->fetchrow_array;
    # Текущая ветка нас не устроит, мы не можем использовать сэмплы от самих себя
    if ($opt{current_branch} && $opt{current_branch} eq $res)
    {
      # берем следующую. Там уже должно что-то отличаться
      ($res) = $sth->fetchrow_array;
    }

    print "Guessing branch = $res\n" if defined $res;
    print "Guessing branch: NOT POSSIBLE!\n" unless defined $res;
    return $res;
}



sub get_samples {
    my %opt = @_;
    my $dbh = _dbh($opt{conf});

    $opt{project} ||= guess_project(%opt);
    if ($opt{branch})
    {
      $opt{cert} ||= guess_cert(%opt);
    } else
    {
      $opt{cert} ||= guess_cert(%opt);
      $opt{branch} ||= guess_branch(%opt);
    }
    die "\nNot enough arguments\n" unless defined $opt{path};

    my $sql = "SELECT sample_name, created_at, sample_file FROM samples WHERE
                      project_name=? AND certification_name=? AND branch_name=? AND trakt_name=? AND target_name=?";

    my $sth = $dbh->prepare($sql);
    my $res = {cert => $opt{cert}, branch => $opt{branch}, project => $opt{project}};

    $res->{count} = $sth->execute($opt{project}, $opt{cert}, $opt{branch}, $opt{trakt}, $opt{target});

    while (my @row = $sth->fetchrow_array) {
        path($opt{path})->child($row[0])->spew_raw($row[2]);
    }
    return $res;
}

sub list_samples
{
    my %opt = @_;
    my $dbh = _dbh($opt{conf});

    $opt{project} ||= guess_project(%opt);

    die "'cert'   option is missing" unless defined $opt{cert};
    die "'branch' option is missing" unless defined $opt{branch};
    die "'trakt'  option is missing" unless defined $opt{trakt};
    die "'target' option is missing" unless defined $opt{target};

    my $sql = "SELECT sample_name FROM samples WHERE
                      project_name=? AND certification_name=? AND branch_name=? AND trakt_name=? AND target_name=?";

    my $sth = $dbh->prepare($sql);
    $sth->execute($opt{project}, $opt{cert}, $opt{branch}, $opt{trakt}, $opt{target});

    my @res = ();
    while (my @row = $sth->fetchrow_array)
    {
        push @res, $row[0];
    }
    return @res;
}

sub upsert_samples {
    my %opt = @_;
    my $dbh = _dbh($opt{conf});

    $opt{project} ||= guess_project(%opt);

     # перед тем как добавлять сэмплы, удалим те что для этой цели и сертификации уже были добавлены
    my $sth = $dbh->prepare("DELETE FROM samples WHERE project_name=? AND certification_name=? AND branch_name=? AND trakt_name=? AND target_name=?");
    my $res = $sth->execute($opt{project}, $opt{cert}, $opt{branch}, $opt{trakt}, $opt{target});
    my $count = 0;
    foreach my $sample (@{$opt{samples}}) {
        my $data = path($sample)->slurp_raw();

        my $sql = "INSERT INTO samples(project_name, certification_name, branch_name, trakt_name, target_name, sample_name, sample_file) VALUES (?, ?, ?, ?, ?, ?, ?)";
        $sth = $dbh->prepare($sql);

        $sth->bind_param(1, $opt{project});
        $sth->bind_param(2, $opt{cert});
        $sth->bind_param(3, $opt{branch});
        $sth->bind_param(4, $opt{trakt});
        $sth->bind_param(5, $opt{target});
        $sth->bind_param(6, basename($sample));
        $sth->bind_param(7, $data, { pg_type => PG_BYTEA });

        $sth->execute;
        $count++;
    }
    print "\nInsertion successful\n";
    return $count;
}

sub get_latest_cert_branch {
    my $conf_name = shift;
    my $dbh = _dbh($conf_name);
    my ($project, $trakt, $target) = @_;

    die "\nNot enough arguments\n" unless defined $target;

    my $sql = "SELECT samples.certification_name, samples.branch_name FROM samples WHERE samples.project_name=? AND samples.trakt_name=? AND samples.target_name=? ORDER BY samples.created_at DESC FETCH FIRST 1 ROWS ONLY";

    my $sth = $dbh->prepare($sql);
    $sth->execute($project, $trakt, $target);

    while (my @row = $sth->fetchrow_array) {
        print "Certification name where were recently added samples: $row[0]\n";
        print "Branch of this certification: $row[1]\n";
    }
}

sub get_latest_cert {
    my $conf_name = shift;
    my $dbh = _dbh($conf_name);
    my ($project, $branch, $trakt, $target) = @_;

    die "\nNot enough arguments\n" unless defined $target;

    my $sql = "SELECT samples.certification_name FROM samples WHERE samples.project_name=? AND samples.branch_name=? AND samples.trakt_name=? AND samples.target_name=? ORDER BY samples.created_at DESC FETCH FIRST 1 ROWS ONLY";

    my $sth = $dbh->prepare($sql);
    $sth->execute($project, $branch, $trakt, $target);

    while (my @row = $sth->fetchrow_array) {
        print "Certification name where were recently added samples: $row[0]\n";
    }
}

sub get_latest_cert_samples {
    my $conf_name = shift;
    my $dbh = _dbh($conf_name);
    my ($project, $branch, $trakt, $target, $path) = @_;

    die "\nNot enough arguments\n" unless defined $path;

    my $sql_cert = "SELECT samples.certification_name FROM samples WHERE samples.project_name=? AND samples.branch_name=? AND samples.trakt_name=? AND samples.target_name=? ORDER BY samples.created_at DESC FETCH FIRST 1 ROWS ONLY";

    my $sth_cert = $dbh->prepare($sql_cert);
    $sth_cert->execute($project, $branch, $trakt, $target);
    my @row_cert = $sth_cert->fetchrow_array;

    $sth_cert->finish;

    my $sql_samples = "SELECT samples.sample_name, samples.sample_file FROM samples WHERE project_name=? AND certification_name=? AND branch_name=? AND trakt_name=? AND target_name=?";

    my $sth_samples = $dbh->prepare($sql_samples);
    $sth_samples->execute($project, $row_cert[0], $branch, $trakt, $target);

    while (my @row = $sth_samples->fetchrow_array) {
        open(my $fh, ">$path/$row[0]");
        print $fh $row[1];
        close($fh) || die "\nCan't close the file $row[0]";
    }

    print "All samples printed and written successfully\n";
}

sub create_project {
    my $conf_name = shift;
    my $dbh = _dbh($conf_name);
    my $project = $_[0];

    die "\nNot enough arguments\n" unless defined $project;

    my $sth = $dbh->prepare("INSERT INTO projects(project_name) values(?)");
    my $num = $sth->execute($project);

    if ($num > 0) {
        print "Insertion successful\n";
    } else {
        print "Unsuccessful\n";
    }
}

sub create_certification {
    my %opt = @_;
    my $dbh = _dbh($opt{conf});

    my ($certification_name, $certification_date) = ($opt{cert}, $opt{date});

    die "Пожалуйста укажите имя добавляемой cертификации последним или предпоследним аргументом" unless defined $certification_name;

    my $num;
    if ($certification_date)
    {
        my $sth = $dbh->prepare("INSERT INTO certifications(certification_name, certification_date) values(?, ?)");
        $num = $sth->execute($certification_name, $certification_date);
    } else
    {
        my $sth = $dbh->prepare("INSERT INTO certifications(certification_name) values(?)");
        $num = $sth->execute($certification_name);
    }

    if ($num > 0) {
        print "Insertion successful\n";
    } else {
        print "Unsuccessful\n";
    }
    return $num;
}

sub create_branch {
    my %opt = @_;
    my $dbh = _dbh($opt{conf});

    $opt{project} ||= guess_project(%opt);

    die "Пожалуйста укажите [Имя новой ветки]" unless defined $opt{branch};

    my $sth = $dbh->prepare("INSERT INTO branches(project_name, branch_name) values(?,?)");
    my $num = $sth->execute($opt{project}, $opt{branch});

    if ($num > 0) {
        print "Insertion successful\n";
    } else {
        print "Unsuccessful\n";
    }
}

sub create_trakt {
    my %opt = @_;
    my $dbh = _dbh($opt{conf});

    $opt{project} ||= guess_project(%opt);

    die "Пожалуйста укажите --trakt=[Имя нового тракта]" unless defined $opt{trakt};

    my $sth = $dbh->prepare("INSERT INTO trakts(project_name, trakt_name) values(?, ?)");
    my $num = $sth->execute($opt{project}, $opt{trakt});

    if ($num > 0) {
        print "Insertion successful\n";
    } else {
        print "Unsuccessful\n";
    }
}

sub create_target {
    my %opt = @_;
    my $dbh = _dbh($opt{conf});

    $opt{project} ||= guess_project(%opt);

    die "Пожалуйста укажите --trakt=[Имя нового тракта]" unless defined $opt{trakt};
    die "Пожалуйста укажите имя добавляемой цели последним аргументом" unless defined $opt{target};

    my $sth = $dbh->prepare("INSERT INTO targets(project_name, trakt_name, target_name) values(?, ?, ?)");
    my $num = $sth->execute($opt{project},$opt{trakt}, $opt{target});

    if ($num > 0) {
        print "Insertion successful\n";
    } else {
        print "Unsuccessful\n";
    }
}

sub delete_project {
    my $conf_name = shift;
    my $dbh = _dbh($conf_name);
    my $project = $_[0];

    die "\nNot enough arguments\n" unless defined $project;

    my $sth = $dbh->prepare("DELETE FROM projects WHERE projects.project_name=? AND projects.project_name NOT IN(SELECT project_name FROM samples WHERE samples.project_name=?)");
    my $num = $sth->execute($project, $project);

    if ($num > 0) {
        print "Deletion successful\n";
    } else {
        print "Unsuccessful\n";
    }
}

sub delete_certification {
    my $conf_name = shift;
    my $dbh = _dbh($conf_name);
    my $certification_name = $_[0];

    die "\nNot enough arguments\n" unless defined $certification_name;

    my $sth = $dbh->prepare("DELETE FROM certifications WHERE certifications.certification_name=? AND certifications.certification_name NOT IN(SELECT certification_name FROM samples WHERE samples.certification_name=?)");
    my $num = $sth->execute($certification_name, $certification_name);

    if ($num > 0) {
        print "Deletion successful\n";
    } else {
        print "Unsuccessful\n";
    }
}

sub delete_branch {
    my $conf_name = shift;
    my $dbh = _dbh($conf_name);
    my $branch = $_[0];

    die "\nNot enough arguments\n" unless defined $branch;

    my $sth = $dbh->prepare("DELETE FROM branches WHERE branch_name=? AND branches.branch_name NOT IN(SELECT branch_name FROM samples WHERE samples.branch_name=?)");
    my $num = $sth->execute($branch, $branch);

    if ($num > 0) {
        print "Deletion successful\n";
    } else {
        print "Unsuccessful\n";
    }
}

sub delete_trakt {
    my $conf_name = shift;
    my $dbh = _dbh($conf_name);
    my $trakt = $_[0];

    die "\nNot enough arguments\n" unless defined $trakt;

    my $sth = $dbh->prepare("DELETE FROM trakt_names WHERE trakt_name=? AND trakt_names.trakt_name NOT IN(SELECT trakt_name FROM samples WHERE samples.trakt_name=?)");
    my $num = $sth->execute($trakt, $trakt);

    if ($num > 0) {
        print "Deletion successful\n";
    } else {
        print "Unsuccessful\n";
    }
}

sub delete_target {
    my $conf_name = shift;
    my $dbh = _dbh($conf_name);
    my $target = $_[0];

    die "\nNot enough arguments\n" unless defined $target;

    my $sth = $dbh->prepare("DELETE FROM target_names WHERE target_name=? AND target_names.target_name NOT IN(SELECT target_name FROM samples WHERE samples.target_name=?)");
    my $num = $sth->execute($target, $target);

    if ($num > 0) {
        print "Delition successful\n";
    } else {
        print "Unsuccessful\n";
    }
}

sub delete_trakt_target {
    my $conf_name = shift;
    my $dbh = _dbh($conf_name);
    my ($trakt, $target) = @_;

    die "\nNot enough arguments\n" unless defined $target;

    my $sth = $dbh->prepare("DELETE FROM trakts WHERE trakt_name=? AND target_name=? AND trakt_name NOT IN(SELECT trakt_name FROM samples WHERE samples.trakt_name=?) AND target_name NOT IN(SELECT target_name FROM samples WHERE samples.target_name=?)");
    my $num = $sth->execute($trakt, $target, $trakt, $target);

    if ($num > 0) {
        print "Delition successful\n";
    } else {
        print "Unsuccessful\n";
    }
}

sub list_certs {
    my %opt = @_;
    my $dbh = _dbh($opt{conf});


    if ( ( exists($opt{trakt}) && !exists($opt{target})) ||
         (!exists($opt{trakt}) &&  exists($opt{target})) )
    {
      die "Список сертификайий мы умеем показывать только для пары trakt-target указывайте пару или не указывайте совсем";
    }

    my $sth;
    if ($opt{trakt})
    {
      $opt{project} ||= guess_project(%opt);
      my $sql = "SELECT DISTINCT certification_name FROM samples WHERE project_name = ? AND trakt_name = ? AND target_name = ?";
      $sth = $dbh->prepare($sql);
      $sth->execute($opt{project}, $opt{trakt}, $opt{target});
    } else
    {
      my $sql = "SELECT certification_name FROM certifications";

      $sth = $dbh->prepare($sql);
      $sth->execute();
    }

    my @res = ();
    while (my @row = $sth->fetchrow_array) {
        push @res, $row[0];
    }
    return @res;
}

sub list_targets {
    my %opt = @_;
    my $dbh = _dbh($opt{conf});

    my $sql = "SELECT target_name FROM targets WHERE trakt_name=?";

    my $sth = $dbh->prepare($sql);
    $sth->execute($opt{trakt});

    my @res = ();
    while (my @row = $sth->fetchrow_array) {
        push @res, $row[0];
    }
    return @res;
}

sub list_branches {
    my %opt = @_;
    my $dbh = _dbh($opt{conf});

    my $sql = "SELECT branch_name FROM branches";

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my @res = ();
    while (my @row = $sth->fetchrow_array) {
        push @res, $row[0];
    }
    return @res;
}

sub list_trakts {
    my %opt = @_;
    my $dbh = _dbh($opt{conf});

    my $sql = "SELECT trakt_name FROM trakts";

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my @res = ();
    while (my @row = $sth->fetchrow_array) {
        push @res, $row[0];
    }
    return @res;
}

sub print_list_certs {
     my @certs = list_certs(@_);
    foreach my $cert_name (@certs)
    {
        print $cert_name, "\n";
    }
}


sub finish {
    my $conf_name = shift;
    my $dbh = _dbh($conf_name);

    $dbh->disconnect;
}
1;
