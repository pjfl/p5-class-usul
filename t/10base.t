# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use File::Basename qw(basename);
use Test::More;
use Test::Deep;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use Class::Usul::Programs;

my $name = basename( $0, qw(.t) );
my $prog = Class::Usul::Programs->new( appclass => q(Class::Usul),
                                       debug    => 0 );

cmp_deeply $prog, methods( encoding => q(UTF-8) ), 'Constructs default object';

ok $prog->config->script eq $name.q(.t), 'Config->script';

ok $prog->config->name eq $name, 'Config->name';

my $text = $prog->add_leader();

ok $text eq "${name}: [no message]", 'Default leader';

$text = $prog->add_leader( 'Dummy' );

ok $text eq '10base: Dummy', 'Text plus leader';

my $bool = $prog->can_call( 'dump_self' ); ok $bool == 1, 'Can call true';

$bool = $prog->can_call( 'add_leader' ); ok $bool == 0, 'Can call false';

my $meta = $prog->get_meta( q(META.yml) );

ok $meta->name eq q(Class-Usul), 'Meta file class';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
