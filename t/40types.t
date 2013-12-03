# @(#)Ident: 40types.t 2013-11-27 13:27 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 4 $ =~ /\d+/gmx );
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

{  package MyNLC;

   use Moo;
   use Class::Usul::Types qw( NullLoadingClass );

   has 'test1' => is => 'ro', isa => NullLoadingClass, default => 'Class::Usul',
      coerce   => NullLoadingClass->coercion;
   has 'test2' => is => 'ro', isa => NullLoadingClass, default => 'Foo::Bar',
      coerce   => NullLoadingClass->coercion;

   $INC{ 'MyNLC.pm' } = __FILE__;
}

my $obj = MyNLC->new;

is $obj->test1, 'Class::Usul', 'NullLoadingClass - loads if exists';
is $obj->test2, 'Class::Null', 'NullLoadingClass - loads Class::Null if not';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
