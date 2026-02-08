#!/usr/bin/perl

use strict;
use Path::Tiny;
use JSON;

my $conf_file = shift @ARGV;
my $out_dir = shift @ARGV;
my $pipe = shift @ARGV;

die "Скрипту надо передать три аргумента: 1.кофиг watchdog'а 2.out-директорию крашера и 3.pipe-файл запускатора" unless ($pipe);


my $json = JSON->new->relaxed;
my $conf = $json->decode(path($conf_file)->slurp);


my $stat_file = path($out_dir)->child("FUZZ-data")->child("fuzz_stats_aggregated.json");
my $eat_stat_file = path($out_dir)->child("EAT_OUT")->child("stats.json");


my $fuzz_stats_json = decode_json($stat_file->slurp_utf8());
my $eat_stats_json = decode_json($eat_stat_file->slurp_utf8());



my $limits = {};
my @limits_keys = keys %{$conf->{limits}};

foreach my $key (@limits_keys)
{
  $limits->{$key} = time_str_to_sec($conf->{limits}->{$key});
}


print "============ fuzz_stats_aggregated.json ===========\n";
print_hash($fuzz_stats_json);

print "\n============ EAT stats.json ===========\n";
print_hash($eat_stats_json);

print "\n";



my $now = $fuzz_stats_json->{last_update};

my $res = {};

$res->{last_path} = $now - $eat_stats_json->{last_queue_time};

foreach my $key (@limits_keys)
{
  if ($res->{$key} > $limits->{$key})
  {
     `echo FINISH reached $key limit >$pipe`;
     print "Достигнуто условие завершение фаззинга. Послали сигнал, ждем принудительно завершения \n"; # Но это сообщение не показывается потому что вотчдог запускается через watch, который печатает после завершения работы скрипта, а у нас дальше sleep
     while (1){sleep 1000}; # Ждем пока снаружи все не пристрелят
     exit(0);
  }
  print "Прогресс: $key == ".$res->{$key}."/".$limits->{$key}."\n";

}


sub print_hash
{
  my $h = shift;
  foreach my $key (sort(keys %$h))
  {
    print $key," => ",$h->{$key}, "\n";
  }
}

sub time_str_to_sec
{
  my $str = shift;
  my $h = {};
  my $mult = {'s' => 1, 'm' => 60, 'h' => 60*60, d => 24*60*60};
  my $res = 0;
  foreach my $tt (split /\s+/,$str)
  {
    my $tt_orig = $tt;
    $tt.="s" if $tt=~/^\d+$/; # по умолчанию секунды
    if ($tt=~/^(\d+)([dhms])$/)
    {
       my $value = $1;
       my $code = $2;
       die "Time string '$str' has at least to '$code' elements " if $h->{$code};
       $h->{$code} = 1;
       $res += $value * $mult->{$code};
    } else
    {
      die "Unknown time element '$tt_orig' in '$str'";
    }
  }
  return $res;
}
