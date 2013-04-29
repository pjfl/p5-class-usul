# @(#)$Ident: 11functions.t 2013-04-29 19:21 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.17.%d', q$Rev: 3 $ =~ /\d+/gmx );
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

use Class::Null;
use English qw( -no_match_vars );
use Exception::Class ( q(TestException) => { fields => [ qw(arg1 arg2) ] } );

use Class::Usul::Functions qw(:all);

is abs_path( catfile( q(t), updir, q(t) ) ), File::Spec->rel2abs( q(t) ),
   'abs_path';

is app_prefix( q(Test::Application) ), q(test_application), 'app_prefix';
is app_prefix( undef ), q(), 'app_prefix - undef arg';

my $list = arg_list( 'key1' => 'value1', 'key2' => 'value2' );

is $list->{key2}, q(value2), 'arg_list';

like assert_directory( q(t) ), qr{ t \z }mx, 'assert_directory - true';
ok ! assert_directory( q(dummy) ),           'assert_directory - false';

is class2appdir( q(Test::Application) ), q(test-application), 'class2appdir';

is classdir( q(Test::Application) ), catdir( qw(Test Application) ), 'classdir';

is classfile( q(Test::Application) ), catfile( qw(Test Application.pm) ),
   'classfile';

is distname( q(Test::Application) ), q(Test-Application), 'distname';

is env_prefix( q(Test::Application) ), q(TEST_APPLICATION), 'env_prefix';

is unescape_TT( escape_TT( q([% test %]) ) ), q([% test %]),
   'escape_TT/unscape_TT';

is find_source( q(Class::Usul::Functions) ),
   abs_path( catfile( qw(lib Class Usul Functions.pm) ) ), 'find_source';

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

my $src  = { 'key2' => 'value2', }; my $dest = {};

merge_attributes $dest, $src, { 'key1' => 'value3', }, [ 'key1', 'key2', ];

is $dest->{key1}, q(value3), 'merge_attributes - default';
is $dest->{key2}, q(value2), 'merge_attributes - source';

is my_prefix( catfile( 'dir', 'prefix_name' ) ), 'prefix', 'my_prefix';

is prefix2class( q(test-application) ), qw(Test::Application), 'prefix2class';

is product( 1, 2, 3, 4 ), 24, 'product';

is split_on__( q(a_b_c), 1 ), q(b), 'split_on__';

is squeeze( q(a  b  c) ), q(a b c), 'squeeze';

is strip_leader( q(test: dummy) ), q(dummy), 'strip_leader';

is sub_name(), q(main), 'sub_name';

is sum( 1, 2, 3, 4 ), 10, 'sum';

is trim( q(  test string  ) ), q(test string), 'trim';

use Class::Usul;
use Class::Usul::Functions qw(create_token throw);

my $ref = Class::Usul->new( config => {
   appclass  => 'Test::Application',
   home      => catfile( qw(lib Class Usul) ),
   localedir => catfile( qw(t locale) ), } );

eval { throw( error => q(eNoMessage) ) }; my $e = $EVAL_ERROR;

like $e->as_string, qr{ eNoMessage }msx, 'try/throw/catch';

my $token = create_token( q(test) );

ok $token eq q(ee26b0dd4af7e749aa1a8ee3c10ae9923f618980772e473f8819a5d4940e0db27ac185f8a0e1d5f84f88bc887fd67b143732c304cc5fa9ad8e6f57f50028a8ff)
   || $token
      eq q(9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08)
   || $token eq q(a94a8fe5ccb19ba61c4c0873d391e987982fbbd3)
   || $token eq q(098f6bcd4621d373cade4e832627b4f6), 'create_token';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
