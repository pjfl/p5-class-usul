use t::boilerplate;

use Test::More;
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
