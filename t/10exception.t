# @(#)Ident: 10exception.t 2013-12-06 16:26 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.34.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );

use Test::More;
use Test::Requires { version => 0.88 };
use Module::Build;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";
use English qw( -no_match_vars );

use_ok 'Class::Usul::Exception';

Class::Usul::Exception->has_exception( 'A' );

my $line = __LINE__; eval { Class::Usul::Exception->throw
   ( error => 'PracticeKill', class => 'A' ) };
my $e = $EVAL_ERROR;

cmp_ok $e->time, '>', 1, 'Has time attribute';

is $e->ignore->[ 1 ], 'Class::Usul::IPC', 'Ignores class';

is $e->rv, 1, 'Returns value';

like $e, qr{ \A main \[ $line / \d+ \]: \s+ PracticeKill }mx, 'Serializes';

is $e->class, 'A', 'Exception is class A';

is $e->instance_of( 'Unexpected' ), 1,
   'Exception class inherits from Unexpected';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
