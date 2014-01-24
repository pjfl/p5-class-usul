# @(#)Ident: 13traits.t 2014-01-09 16:34 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.37.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir catfile updir );
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

use Test::Requires         "${perl_ver}";
use Class::Usul::Functions qw( exception );
use File::Basename         qw( basename );

{  package MyCIProg;

   use Moo;

   with 'Class::Usul::TraitFor::ConnectInfo';

   sub config {
      return { ctrldir => 't', };
   }

   1;
}

my $prog = MyCIProg->new;
my $info = $prog->get_connect_info( $prog, { database => 'test' } );

is $info->[ 1 ], 'root', 'Connect info - user';
is $info->[ 2 ], 'test', 'Connect info - password';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
