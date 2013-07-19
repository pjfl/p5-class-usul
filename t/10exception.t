# @(#)Ident: 10exception.t 2013-05-08 21:08 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.22.%d', q$Rev: 12 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

BEGIN {
   my $current = eval { Module::Build->current };
   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use_ok 'Class::Usul::Exception';

my $e = Class::Usul::Exception->caught( 'PracticeKill' ); my $line = __LINE__;

cmp_ok $e->time, '>', 1, 'Has time attribute';
is $e->ignore->[ 1 ], 'Class::Usul::IPC', 'Ignores class';
like $e, qr{ \A main \[ $line / \d+ \]: \s+ PracticeKill }mx, 'Serializes';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
