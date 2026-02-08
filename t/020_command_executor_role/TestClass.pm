package TestClass;

use Moose;

use FindBin;
use lib $FindBin::Bin."/../lib";
use Path::Tiny;

with 'Trakt::CommandExecutorRole';

sub cache_dir
{
  my $self = shift;
  return path($FindBin::Bin."/020_command_executor_role/cache");
}

sub exchange_dir
{
  my $self = shift;
  return path($FindBin::Bin."/020_command_executor_role/exchange");
}

sub run
{
  print "Класс TestClass работает!!!\n";
}

1;
