# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Test::More;
use Test::Deep;

BEGIN {
   if ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
       || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) {
      plan skip_all => q(CPAN Testing stopped);
   }

   plan tests => 3;
}

use_ok q(Class::Usul::Programs);

my $prog = Class::Usul::Programs->new( n => 1 );

cmp_deeply( $prog, methods(appclass => q(10base),
                           encoding => q(UTF-8),
                           name => q(10base),
                           prefix => q(10base)), 'constructs default object' );

my $meta = $prog->get_meta( q(META.yml) );

ok( $meta->name eq q(Class-Usul), q(meta file class) );

# Local Variables:
# mode: perl
# tab-width: 3
# End:
