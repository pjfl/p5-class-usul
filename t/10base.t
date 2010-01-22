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

   plan tests => 4;
}

use_ok q(Class::Usul::Programs);

my $prog = Class::Usul::Programs->new( n => 1 );

cmp_deeply( $prog, methods(appclass => q(10base),
                           encoding => q(UTF-8),
                           name => q(10base),
                           prefix => q(10base)), 'constructs default object' );

my $meta = $prog->get_meta( q(META.yml) );

ok( $meta->name eq q(Class-Usul), 'meta file class' );

my $token = $prog->create_token( 'South Park' );

ok( $token eq q(d1b15d855a06b6e5d7c9468bb00ebb7335c839027f0f2e580bdb0280400e26ea)
    || $token eq q(2b36373e851c5dc1f815a391ded0f5cf51d08694)
    || $token eq q(d279eb03080cdc91c708349912867b15), 'create token' );

# Local Variables:
# mode: perl
# tab-width: 3
# End:
