# @(#)$Id$

package CPANTesting;

use strict;
use warnings;

my $uname = qx(uname -a);

sub broken_toolchain {
   return 0;
}

sub exceptions {
   $uname =~ m{ slack64 }mx and return 'Stopped Bingos slack64';
   return 0;
}

1;

__END__