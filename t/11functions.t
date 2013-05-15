# @(#)$Ident: 11functions.t 2013-05-13 15:10 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.21.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use Class::Usul::Functions qw(:all);
use English qw( -no_match_vars );

is abs_path( catfile( q(t), updir, q(t) ) ), File::Spec->rel2abs( q(t) ),
   'abs_path';

is app_prefix( q(Test::Application) ), q(test_application), 'app_prefix';
is app_prefix( undef ), q(), 'app_prefix - undef arg';

my $list = arg_list( 'key1' => 'value1', 'key2' => 'value2' );

is $list->{key2}, q(value2), 'arg_list';

like assert_directory( q(t) ), qr{ t \z }mx, 'assert_directory - true';
ok ! assert_directory( q(dummy) ),           'assert_directory - false';

my $before = time; my $id = bsonid_time( bsonid ); my $after = time;
my $bool   = $before <= $id && $id <= $after ? 1 : 0;

ok $bool, 'bsonid_time';

$before = time; $id = bson64id_time( bson64id ); $after = time;
$bool   = $before <= $id && $id <= $after ? 1 : 0;

ok $bool, 'bson64id_time';

sub build_test { my $v = shift; return $v + 1 } my $f = sub { 1 };

is build( \&build_test, $f )->(), 2, 'build';

is class2appdir( q(Test::Application) ), q(test-application), 'class2appdir';

is classdir( q(Test::Application) ), catdir( qw(Test Application) ), 'classdir';

is classfile( q(Test::Application) ), catfile( qw(Test Application.pm) ),
   'classfile';

my $token = create_token( q(test) );

ok $token eq q(ee26b0dd4af7e749aa1a8ee3c10ae9923f618980772e473f8819a5d4940e0db27ac185f8a0e1d5f84f88bc887fd67b143732c304cc5fa9ad8e6f57f50028a8ff)
   || $token
      eq q(9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08)
   || $token eq q(a94a8fe5ccb19ba61c4c0873d391e987982fbbd3)
   || $token eq q(098f6bcd4621d373cade4e832627b4f6), 'create_token';

is distname( q(Test::Application) ), q(Test-Application), 'distname';

is env_prefix( q(Test::Application) ), q(TEST_APPLICATION), 'env_prefix';

is unescape_TT( escape_TT( q([% test %]) ) ), q([% test %]),
   'escape_TT/unscape_TT';

is find_source( q(Class::Usul::Functions) ),
   abs_path( catfile( qw(lib Class Usul Functions.pm) ) ), 'find_source';

#warn fqdn( 'localhost' )."\n";
#warn fullname()."\n";
#warn get_user()->name."\n";

is hex2str( '41' ), 'A', 'hex2str - A';

is home2appldir( catdir( qw(opt myapp v0.1 lib MyApp) ) ),
   catdir( qw(opt myapp v0.1) ), 'home2appldir';

ok is_arrayref( [] ),   'is_arrayref - true';
ok ! is_arrayref( {} ), 'is_arrayref - false';

ok is_coderef( sub {} ), 'is_coderef - true';
ok ! is_coderef( {} ),   'is_coderef - false';

ok is_hashref( {} ),   'is_hashref - true';
ok ! is_hashref( [] ), 'is_hashref - false';

ok is_member( 2, 1, 2, 3 ),   'is_member - true';
ok ! is_member( 4, 1, 2, 3 ), 'is_member - false';

#warn loginid()."\n";
#warn logname()."\n";

my $src = { 'key2' => 'value2', }; my $dest = {};

merge_attributes $dest, $src, { 'key1' => 'value3', }, [ 'key1', 'key2', ];

is $dest->{key1}, q(value3), 'merge_attributes - default';
is $dest->{key2}, q(value2), 'merge_attributes - source';

is my_prefix( catfile( 'dir', 'prefix_name' ) ), 'prefix', 'my_prefix';

is pad( 'x', 7, 'X', 'both' ), 'XXXxXXX', 'pad';

is prefix2class( q(test-application) ), qw(Test::Application), 'prefix2class';

is product( 1, 2, 3, 4 ), 24, 'product';

is split_on__( q(a_b_c), 1 ), q(b), 'split_on__';

is split_on_dash( 'a-b-c', 1 ), 'b', 'split_on_dash';

is squeeze( q(a  b  c) ), q(a b c), 'squeeze';

is strip_leader( q(test: dummy) ), q(dummy), 'strip_leader';

is sub_name(), q(main), 'sub_name';

is sum( 1, 2, 3, 4 ), 10, 'sum';

eval { throw( error => q(eNoMessage) ) }; my $e = $EVAL_ERROR;

like $e->as_string, qr{ eNoMessage }msx, 'try/throw/catch';

is trim( q(  test string  ) ), q(test string), 'trim';

is { zip( qw(a b c), qw(1 2 3) ) }->{b}, 2, 'zip';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
