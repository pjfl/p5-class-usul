# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Test::More;

BEGIN {
   if ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
       || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) {
      plan skip_all => q(CPAN Testing stopped);
   }

   plan tests => 2;
}

use_ok q(Class::Usul::Programs);

my $prog = Class::Usul::Programs->new( n => 1 );
my $meta = $prog->get_meta( q(META.yml) );

ok( $meta->name eq q(Class-Usul), q(meta file class) );

# Local Variables:
# mode: perl
# tab-width: 3
# End:
