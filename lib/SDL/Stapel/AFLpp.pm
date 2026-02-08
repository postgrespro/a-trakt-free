package SDL::Stapel::AFLpp;

use Moose;
extends 'SDL::Stapel';

with "SDL::Stapel::AFLpp::DefaultBuildSet";

use SDL::Stapel::AFLpp::SrcOrigin::Git;

has "+src_origin_class" => (default => "SDL::Stapel::AFLpp::SrcOrigin::Git");
has "+is_insource_build" => (default => 1);

sub configure
{
  # do nothing
  # AFL++ конфигурирования не требует. Сразу сборка
}

1;
