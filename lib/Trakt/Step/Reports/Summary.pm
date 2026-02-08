package Trakt::Step::Reports::Summary;

use Moose::Role;
use JSON;
use Term::ANSIColor;

before 'after_run' => sub
{
  my $self = shift;

  # для доступа к целям тракта обращаемся непосредственно к тракту, поскольку
  # в шаге Summary метод targets возвращает пустой список.
  my @targets = $self->trakt->targets;

  my $summary_file = $self->trakt->res_dir->child("summary");

  open(HF, '>', $summary_file) or die $!;
  print(HF "Название исследования: ", $self->trakt->full_name, "\n");
  print(HF "Имя ветки: ", $self->trakt->branch, "\n");
  my %config = %{$self->trakt->conf->{cert}};
  print(HF "Имя сертификации: $config{name}\n");

  foreach my $target_name (@targets)
  {
    my $js = JSON->new->allow_nonref;
    my $stat_json_file = $self->target($target_name)->res_dir->child('stat.json');
    my $stat_json_hash = $js->decode($stat_json_file->slurp);
    my %hangs = %{$stat_json_hash->{hangs}};
    my $hangs_total = keys %hangs;
    my $real_hangs = 0;
    my $false_hangs = 0;
    my $min_hang_time;
    my $max_hang_time;

    if ($hangs_total)
    {
      my @times = ();

      for my $hang_name (keys %hangs)
      {
        $real_hangs++ if ($hangs{$hang_name}->{is_real_hang});
        push @times, $hangs{$hang_name}->{time} unless ($hangs{$hang_name}->{is_real_hang});
      }
      $false_hangs = $hangs_total - $real_hangs;

      @times = sort { $a <=> $b } @times;
      $min_hang_time = sprintf('%0.2f', $times[0]);
      $max_hang_time = sprintf('%0.2f', $times[-1]);
    }

    my %crashes = %{$stat_json_hash->{crashes}};
    my $number_of_crashes = keys %crashes;
    my %crashes_by_type;
    for my $crash_name (keys %crashes)
    {
      my $crash_type = $crashes{$crash_name}->{crash_type};
    $crashes_by_type{$crash_type} //= 0; # Явно устанавливаем счетчик на 0 если он еще в значении undef https://perldoc.perl.org/perlop#Logical-Defined-Or
    $crashes_by_type{$crash_type}++;
    }

    print HF "\nЦель: ", colored("$target_name", 'bold bright_white'), "\n";

    print HF colored("\tЗависаний: $real_hangs", $real_hangs? 'bold bright_red' :'bright_white'), "\t";
    if ($false_hangs)
    {
          print HF "ложных: ", colored("$false_hangs",'bold bright_yellow'), " ";
          print HF " (", colored("$min_hang_time - $max_hang_time c.", 'bright_white'), ")";
    }
    print HF "\n";

    print HF colored("\tКрэшей: $number_of_crashes", $number_of_crashes ? 'bold bright_red' : 'bright_white'), "\n";
    for my $crash_type (keys %crashes_by_type)
    {
      print HF "\t    ", colored("$crash_type: $crashes_by_type{$crash_type}", 'bold bright_red'), "\n";
    }
  }
  close(HF);

};

1;
