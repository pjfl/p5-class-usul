# @(#)$Ident: 21ipc.t 2013-04-29 19:20 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.20.%d', q$Rev: 1 $ =~ /\d+/gmx );
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
   sub alert { warn '[ALERT] '.$_[ 1 ]."\n" }
   sub debug { warn '[DEBUG] '.$_[ 1 ]."\n" }
   sub error { warn '[ERROR] '.$_[ 1 ]."\n" }
   sub fatal { warn '[ALERT] '.$_[ 1 ]."\n" }
   sub info  { warn '[ALERT] '.$_[ 1 ]."\n" }
   sub warn  { warn '[WARNING] '.$_[ 1 ]."\n" }
}

use Class::Usul::Programs;
use Class::Usul::Constants qw(EXCEPTION_CLASS);

my $osname = lc $OSNAME;
my $perl   = $EXECUTABLE_NAME;
my $prog   = Class::Usul::Programs->new( appclass => q(Class::Usul),
                                         config   => { logsdir => q(t),
                                                       tempdir => q(t), },
                                         log      => Logger->new,
                                         method   => q(dump_self),
                                         nodebug  => 1,
                                         quiet    => 1, );

sub popen_test {
   my $want = shift; my $r = eval { $prog->ipc->popen( @_ ) };

   $EVAL_ERROR     and return $EVAL_ERROR;
   $want eq q(out) and return $r->out;
   $want eq q(rv)  and return $r->rv;
   return $r;
}

my $cmd = "${perl} -v"; my $r;

like popen_test( q(out), $cmd ), qr{ larry \s+ wall }imsx, 'popen';

$cmd = "${perl} -e \"exit 2\""; $r = popen_test( q(out), $cmd );

is ref $r, EXCEPTION_CLASS, 'popen exception is right class';

like $r, qr{ Unknown \s+ error }msx, 'popen default error string';

is popen_test( q(rv), $cmd, { expected_rv => 2 } ), 2, 'popen expected rv';

$cmd = "${perl} -e \"die q(In a pit of fire)\"";

like popen_test( q(out), $cmd ), qr{ pit \s+ of \s+ fire }msx,
   'popen expected error string';

$cmd = "${perl} -e \"print <>\"";

SKIP: {
   $osname eq q(mswin32) and skip 'popen capture stdin - not on MSWin32', 1;

   is popen_test( q(out), $cmd, { in => [ 'some text' ] } ), 'some text',
      'popen captures stdin and stdout';
}

sub run_cmd_test {
   my $want = shift; my $r = eval { $prog->run_cmd( @_ ) };

   $EVAL_ERROR     and return $EVAL_ERROR;
   $want eq q(out) and return $r->out;
   $want eq q(rv)  and return $r->rv;
   return $r;
}

SKIP: {
   $osname eq q(mswin32) and skip 'run_cmd system test - not on MSWin32', 5;

   $cmd = "${perl} -v"; $r = run_cmd_test( q(out), $cmd );

   like $r, qr{ larry \s+ wall }imsx, 'run_cmd system';

   $cmd = "${perl} -e \"exit 2\""; $r = run_cmd_test( q(), $cmd );

   is ref $r, EXCEPTION_CLASS, 'run_cmd system exception is right class';

   like $r, qr{ Unknown \s+ error }msx, 'run_cmd system default error string';

   is run_cmd_test( q(rv), $cmd, { expected_rv => 2 } ), 2,
      'run_cmd system expected rv';

   like run_cmd_test( q(out), $cmd, { async => 1 } ), qr{ background }msx,
      'run_cmd system async';
}

SKIP: {
   $osname eq q(mswin32) and skip 'run_cmd IPC::Run test - not on MSWin32', 6;

   eval { require IPC::Run }; $EVAL_ERROR
      and skip 'IPC::Run test - not installed', 6;

   $cmd = [ $perl, '-v' ];

   like run_cmd_test( q(out), $cmd ), qr{ larry \s+ wall }imsx,
      'run_cmd IPC::Run';

   $cmd = [ $perl, '-e', 'exit 1' ];

   like run_cmd_test( q(), $cmd ), qr{ Unknown \s+ error }msx,
      'run_cmd IPC::Run default error string';

   is run_cmd_test( q(rv), $cmd, { expected_rv => 1 } ), 1,
      'run_cmd IPC::Run expected rv';

   $cmd = [ $perl, '-v' ];

   like run_cmd_test( q(out), $cmd, { async => 1 } ), qr{ background }msx,
      'run_cmd IPC::Run async';

   $cmd = [ sub { print 'Hello World' } ];

   like run_cmd_test( q(out), $cmd, { async => 1 } ), qr{ background }msx,
      'run_cmd IPC::Run async coderef';

   unlike run_cmd_test( q(rv), $cmd, { async => 1 } ), qr{ \(-1\) }msx,
      'run_cmd IPC::Run async coderef captures pid';
}

# This fails on some platforms. The stderr is not redirected as expected
#eval { $prog->run_cmd( "unknown_command_xa23sd3", { debug => 1 } ) };

#ok $EVAL_ERROR =~ m{ unknown_command }mx, 'unknown command';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
