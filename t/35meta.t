use strict;
use warnings;
use File::Spec::Functions qw( catdir catfile tmpdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

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

{  package Consumer;

   use Moo;

   with q(Class::Usul::TraitFor::MetaData);

   sub config {
      return bless {}, 'Consumer::Config';
   }

   sub get_meta {
      my $self = shift; return $self->get_package_meta( 't' );
   }

   $INC{ 'Consumer.pm' } = __FILE__;
}

my $meta = Consumer->new->get_meta;

is $meta->name, 'Class-Usul', 'Meta object - name';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
