# @(#)$Ident: CPANTesting.pm 2013-05-10 21:16 pjf ;
# Bob-Version: 1.7

package CPANTesting;

use strict;
use warnings;

use Sys::Hostname; my $host = lc hostname; my $osname = lc $^O;

# Is this an attempted install on a CPAN testing platform?
sub is_testing { !! ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
                 || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) }

sub should_abort {
   is_testing() or return 0;

   $host eq q(xphvmfred) and return
      "Terminated Stauner ${host} - cc06993e-a5e9-11e2-83b7-87183f85d660";

   return 0;
}

sub test_exceptions {
   my $p = shift; is_testing() or return 0;

   $p->{stop_tests} and return 'CPAN Testing stopped in Build.PL';

   $osname eq q(mirbsd)          and return 'Mirbsd OS unsupported';
   $host   =~ m{ nigelhorne }msx and return
      "Stopped Horne   ${host} - irrelevant Perl versions";
#   $host   eq q(c-9d2392d06fcb4) and return
#      "Stopped Ciornii ${host} - aa18dea5-6bfb-1014-97a2-fbb5402793bb";
#   $host   eq q(k83)             and return
#      "Stopped Konig   ${host} - cfd60888-aea9-11e2-882d-0004c1508286";
   return 0;
}

1;

__END__
