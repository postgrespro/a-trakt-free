#!/usr/bin/perl

use strict;
use Path::Tiny;

my $path = path("/home/nataraj/dev/samples-tmp-storage");

print "./test.pl conf/samples.json create-cert cert-test\n";
`./test.pl conf/samples.json create-cert test_cert`;

foreach my $trakt_p ($path->children)
{
  next if $trakt_p->is_file;
  my $trakt_name = $trakt_p->basename;
  next if  $trakt_name eq '.git';

  print "---------$trakt_p------ \n";
 
  foreach my $target_p ($trakt_p->children)
  {
    my $target_name = $target_p->basename;
    print "$target_name\n";
    print "./test.pl conf/samples.json create-target --trakt=$trakt_name $target_name\n";
    print `./test.pl conf/samples.json create-target --trakt=$trakt_name $target_name`;
    print "-\n";
    print "./test.pl conf/samples.json upsert-samples -p postgrespro -c test_cert -b std-14 --trakt=$trakt_name --target=$target_name $target_p/*\n";
    print `./test.pl conf/samples.json upsert-samples -p postgrespro -c test_cert -b std-14 --trakt=$trakt_name --target=$target_name $target_p/*`;

  }
}


