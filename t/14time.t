# @(#)$Ident: 14time.t 2013-04-29 19:21 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.18.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use Class::Null;
use English qw( -no_match_vars );
use Exception::Class ( q(TestException) => { fields => [ qw(arg1 arg2) ] } );

use Math::BigInt;

Math::BigInt->config()->{lib} eq q(Math::BigInt::GMP)
   and plan skip_all => 'Math::BigInt::GMP installed RT#33816';

use Class::Usul::Time qw(str2date_time str2time time2str);

is time2str( undef, 0, q(UTC) ), q(1970-01-01 00:00:00), 'stamp';

my $dt = q().str2date_time( q(11/9/2007 14:12), q(GMT) );

is $dt, q(2007-09-11T14:12:00), 'str2date_time';

is str2time( q(2007-07-30 01:05:32), q(BST) ), q(1185753932), 'str2time/1';

is str2time( q(30/7/2007 01:05:32), q(BST) ), q(1185753932), 'str2time/2';

is str2time( q(30/7/2007), q(BST) ), q(1185750000), 'str2time/3';

is str2time( q(2007.07.30), q(BST) ), q(1185750000), 'str2time/4';

is str2time( q(1970/01/01), q(GMT) ), q(0), 'str2time/epoch';

is time2str( q(%Y-%m-%d), 0, q(UTC) ), q(1970-01-01), 'time2str/1';

is time2str( q(%Y-%m-%d %H:%M:%S), 1185753932, q(BST) ),
   q(2007-07-30 01:05:32), 'time2str/2';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
