use FindBin;
use lib $FindBin::Bin."/../lib";
# Хелпер
use lib $FindBin::Bin."/lib";

use Test::More tests => 3;

require_ok('Code::CovTool');
require_ok('Code::CovTool::Sources');
require_ok('Local::Test::Helper');

done_testing;
