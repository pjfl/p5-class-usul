use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
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
use Try::Tiny;
use Unexpected::Functions qw( catch_class );

{  package MyNLC;

   use Moo;
   use Class::Usul::Types qw( NullLoadingClass );

   has 'test1' => is => 'ro', isa => NullLoadingClass, default => 'Class::Usul',
      coerce   => NullLoadingClass->coercion;
   has 'test2' => is => 'ro', isa => NullLoadingClass, default => 'FooX::BarT',
      coerce   => NullLoadingClass->coercion;

   $INC{ 'MyNLC.pm' } = __FILE__;
}

my $obj = MyNLC->new;

is $obj->test1, 'Class::Usul', 'NullLoadingClass - loads if exists';
is $obj->test2, 'Class::Null', 'NullLoadingClass - loads Class::Null if not';

{  package MyDT;

   use Moo;
   use Class::Usul::Types qw( DateTimeType );

   has 'dt1' => is => 'ro',   isa => DateTimeType,
      default => '11/9/2001 12:00 UTC', coerce => DateTimeType->coercion;
   has 'dt2' => is => 'lazy', isa => DateTimeType,
      default => 'today at noon', coerce => DateTimeType->coercion;

   $INC{ 'MyDT.pm' } = __FILE__;
}

$obj = MyDT->new;

is $obj->dt1, '2001-09-11T12:00:00', 'DateTimeType - coerces from string';

eval { $obj->dt2 }; my $e = $EVAL_ERROR;

is $e->class, 'DateTimeCoercion', 'DateTimeType - throw expected class';

my $ret = '';

try         { $obj->dt2 }
catch_class [ 'DateTimeCoercion' => sub { $ret = 'handled' } ];

is $ret, 'handled', 'DateTimeType - can catch_class';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
