package Trakt::Step::Postprocess;

use Moose;
extends 'Trakt::Step';

1;


package Trakt::Step::Postprocess::Target;

use Moose;
extends 'Trakt::Target';

with 'Trakt::Step::Postprocess::Hangs', 'Trakt::Step::Postprocess::Crashes';

1;
