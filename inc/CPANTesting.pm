# @(#)$Id$
# Bob-Version: 1.7

package CPANTesting;

use strict;
use warnings;

use Sys::Hostname; my $host = lc hostname; my $osname = lc $^O;

# Is this an attempted install on a CPAN testing platform?
sub is_testing { !! ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
                 || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) }

sub should_abort {
   return 0;
}

sub test_exceptions {
   my $p = shift; is_testing() or return 0;

   $p->{stop_tests} and return 'CPAN Testing stopped in Build.PL';

   $osname eq q(mirbsd)          and return 'Mirbsd  OS unsupported';
   $host   eq q(slack64)         and return "Stopped Bingos ${host}";
   $host   eq q(falco)           and return "Stopped Bingos ${host}";
   $host   =~ m{ nigelhorne }msx and return 'Stopped Horne bad Perl version';
   $host   eq q(c-9d2392d06fcb4) and return "Stopped Ciornii ${host} - failed dependency aa18dea5-6bfb-1014-97a2-fbb5402793bb";
   return 0;
}

1;

__END__
