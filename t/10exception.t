# @(#)Ident: 10exception.t 2013-08-18 10:53 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.25.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );

use Module::Build;
use Test::More;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";

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
