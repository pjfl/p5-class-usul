# @(#)$Ident: 05kwalitee.t 2013-04-29 19:21 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.21.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   if (!-e catfile( $Bin, updir, q(MANIFEST.SKIP) )) {
      plan skip_all => 'Kwalitee test only for developers';
   }
}

eval { require Test::Kwalitee; };

plan skip_all => 'Test::Kwalitee not installed' if ($EVAL_ERROR);

# Since we now use a custom Moose exporter this metric is no longer valid
Test::Kwalitee->import( tests => [ qw(-use_strict) ] );

unlink q(Debian_CPANTS.txt);

# Local Variables:
# mode: perl
# tab-width: 3
# End:
