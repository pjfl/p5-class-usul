# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.11.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions qw( catdir catfile tmpdir updir );
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use English qw( -no_match_vars );
use File::Basename;

{  package Logger;

   sub new   { return bless {}, __PACKAGE__ }
   sub alert { warn '[ALERT] '.$_[ 1 ] }
   sub debug { warn '[DEBUG] '.$_[ 1 ] }
   sub error { warn '[ERROR] '.$_[ 1 ] }
   sub fatal { warn '[ALERT] '.$_[ 1 ] }
   sub info  { warn '[ALERT] '.$_[ 1 ] }
   sub warn  { warn '[WARNING] '.$_[ 1 ] }
}

use Class::Usul::Programs;
use Class::Usul::Constants qw(EXCEPTION_CLASS);

my $perl = $EXECUTABLE_NAME;
my $prog = Class::Usul::Programs->new( appclass => q(Class::Usul),
                                       config   => { logsdir => q(t),
                                                     tempdir => q(t), },
                                       method   => q(dump_self),
                                       nodebug  => 1,
                                       quiet    => 1, );

sub run_cmd {
   my $want = shift; my $r = eval { $prog->run_cmd( @_ ) };

   $EVAL_ERROR     and return $EVAL_ERROR;
   $want eq q(out) and return $r->out;
   $want eq q(rv)  and return $r->rv;
   return $r;
}

my $cmd = "${perl} -e 'print \"Hello World\"'"; my $r = run_cmd( q(out), $cmd );

is $r, q(Hello World), 'run_cmd system';

$cmd = "${perl} -e 'exit 1'"; $r = run_cmd( q(), $cmd );

is ref $r, EXCEPTION_CLASS, 'exception is right class';

like $r, qr{ Unknown \s+ error }msx, 'run_cmd system unexpected rv';

is run_cmd( q(rv), $cmd, { expected_rv => 1 } ), 1,
   'run_cmd system expected rv';

like run_cmd( q(out), $cmd, { async => 1 } ), qr{ background }msx,
   'run_cmd system async';

$cmd = [ $perl, '-e', 'print "Hello World"' ];

is run_cmd( q(out), $cmd ), 'Hello World', 'run_cmd IPC::Run';

$cmd = [ $perl, '-e', 'exit 1' ];

like run_cmd( q(), $cmd ), qr{ Unknown \s+ error }msx,
   'run_cmd IPC::Run unexpected rv';

is run_cmd( q(rv), $cmd, { expected_rv => 1 } ), 1,
   'run_cmd IPC::Run expected rv';

$cmd = [ $perl, '-e', 'print "Hello World"' ];

like run_cmd( q(out), $cmd, { async => 1 } ), qr{ background }msx,
   'run_cmd IPC::Run async';

$cmd = [ sub { print 'Hello World' } ];

like run_cmd( q(out), $cmd, { async => 1 } ), qr{ background }msx,
   'run_cmd IPC::Run async coderef';

unlike run_cmd( q(rv), $cmd, { async => 1 } ), qr{ \(-1\) }msx,
   'run_cmd IPC::Run async coderef captures pid';

# This fails on some platforms. The stderr is not redirected as expected
#eval { $prog->run_cmd( "unknown_command_xa23sd3", { debug => 1 } ) };

#ok $EVAL_ERROR =~ m{ unknown_command }mx, 'unknown command';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
