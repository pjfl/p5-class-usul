# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;
use Test::Deep;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => q(CPAN Testing stopped);

   plan tests => 33;
}

use_ok q(Class::Usul::Programs);

my $prog = Class::Usul::Programs->new( appclass => q(Class::Usul),
                                       debug    => 0 );

cmp_deeply( $prog, methods(appclass => q(Class::Usul),
                           encoding => q(UTF-8),
                           name => q(10base)), 'constructs default object' );

ok( $prog->app_prefix( q(Test::Application) ) eq q(test_application),
    q(app_prefix) );

my $list = $prog->arg_list( 'key1' => 'value1', 'key2' => 'value2' );

ok( $prog->basename( catfile( qw(fake root dummy) ) ) eq q(dummy),
    q(basename) );

ok( $list->{key2} eq q(value2), q(arg_list) );

eval { $prog->throw( error => q(eNoMessage) ) };

my $e = $prog->catch();

ok( $e->as_string eq q(eNoMessage), q(try/throw/catch) );

ok( $prog->catdir( q(dir1), q(dir2) ) =~ m{ dir1 . dir2 }mx, q(catdir) );

ok( $prog->catfile( q(dir1), q(file1) ) =~ m{ dir1 . file1 }mx, q(catfile) );

ok( $prog->class2appdir( q(Test::Application) ) eq q(test-application),
    q(class2appdir) );

ok( $prog->classfile( q(Test::Application) )
    eq catfile( qw(Test Application.pm) ), q(classfile) );

my $token = $prog->create_token( 'South Park' );

ok( $token
    eq q(d1b15d855a06b6e5d7c9468bb00ebb7335c839027f0f2e580bdb0280400e26ea)
    || $token eq q(2b36373e851c5dc1f815a391ded0f5cf51d08694)
    || $token eq q(d279eb03080cdc91c708349912867b15), 'create token' );

ok( $prog->dirname( catfile( qw(dir1 file1) ) ) eq q(dir1), q(dirname) );

ok( $prog->distname( q(Test::Application) ) eq q(Test-Application),
    q(distname) );

ok( $prog->env_prefix( q(Test::Application) ) eq q(TEST_APPLICATION),
    q(env_prefix) );

ok( $prog->unescape_TT( $prog->escape_TT( q([% test %]) ) ) eq q([% test %]),
    q(escape_TT/unscape_TT));

ok( $prog->home2appl( catdir( qw(opt myapp v0.1 lib MyApp) ) )
    eq catdir( qw(opt myapp v0.1) ), q(home2appl) );

my $io = $prog->io( q(t) ); my $entry;

while (defined ($entry = $io->next)) {
   $entry->filename eq q(10base.t) and last;
}

ok( (defined $entry and $entry->filename eq q(10base.t)), q(IO::next) );

ok( $prog->is_member( 2, 1, 2, 3 ), q(is_member) );

ok( $prog->stamp( 0 ) eq q(1970-01-01 01:00:00), q(stamp) );

ok( q().$prog->str2date_time( q(11/9/2007 14:12) )
    eq q(2007-09-11T13:12:00), q(str2date_time) );

ok( $prog->str2time( q(2007-07-30 01:05:32), q(BST) )
    eq q(1185753932), q(str2time/1) );

ok( $prog->str2time( q(30/7/2007 01:05:32), q(BST) )
    eq q(1185753932), q(str2time/2) );

ok( $prog->str2time( q(30/7/2007), q(BST) ) eq q(1185750000),
    q(str2time/3) );

ok( $prog->str2time( q(2007.07.30), q(BST) ) eq q(1185750000),
    q(str2time/4) );

ok( $prog->str2time( q(1970/01/01), q(GMT) ) eq q(0), q(str2time/epoch) );

ok( $prog->strip_leader( q(test: dummy) ) eq q(dummy), q(strip_leader) );

my $tempfile = $prog->tempfile;

ok( $tempfile, q(call/tempfile) );

$prog->io( $tempfile->pathname )->touch;

ok( -f $tempfile->pathname, q(touch/tempfile) );

$prog->delete_tmp_files;

ok( ! -f $tempfile->pathname, q(delete_tmp_files) );

ok( $prog->time2str( q(%Y-%m-%d), 0 ) eq q(1970-01-01), q(time2str/1) );

ok( $prog->time2str( q(%Y-%m-%d %H:%M:%S), 1185753932 )
    eq q(2007-07-30 01:05:32), q(time2str/2) );

ok( $prog->decrypt( q(test), $prog->encrypt( q(test), 'Plain text' ) )
    eq 'Plain text', 'encrypt/decrypt' );

my $meta = $prog->get_meta( q(META.yml) );

ok( $meta->name eq q(Class-Usul), 'meta file class' );

# Local Variables:
# mode: perl
# tab-width: 3
# End:
