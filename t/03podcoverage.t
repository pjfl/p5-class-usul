use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

use Test::More;

BEGIN {
   $ENV{AUTHOR_TESTING}
      or plan skip_all => 'POD coverage test only for developers';
}

use English qw( -no_match_vars );

eval "use Test::Pod::Coverage 1.04";

$EVAL_ERROR and plan skip_all => 'Test::Pod::Coverage 1.04 required';

my $skip = 'AF_UNIX | PF_UNSPEC | WNOHANG';

all_pod_coverage_ok({ also_private => [ qr{ (?: $skip ) }mx ] });

# Local Variables:
# mode: perl
# tab-width: 3
# End:
