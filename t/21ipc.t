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
use File::Basename;

{  package Logger;

   sub new   { return bless {}, __PACKAGE__ }
   sub alert { warn '[ALERT] '.$_[ 1 ]."\n" }
   sub debug { }
   sub error { warn '[ERROR] '.$_[ 1 ]."\n" }
   sub fatal { warn '[ALERT] '.$_[ 1 ]."\n" }
   sub info  { warn '[ALERT] '.$_[ 1 ]."\n" }
   sub warn  { warn '[WARNING] '.$_[ 1 ]."\n" }
}

use Class::Usul::Programs;
use Class::Usul::Constants qw(EXCEPTION_CLASS);

my $osname = lc $OSNAME;
my $perl   = $EXECUTABLE_NAME;
my $prog   = Class::Usul::Programs->new( appclass => 'Class::Usul',
                                         config   => { cache_ttys => 0,
                                                       logsdir    => 't',
                                                       tempdir    => 't', },
                                         log      => Logger->new,
                                         method   => 'dump_self',
                                         noask    => 1,
                                         quiet    => 1, );

sub popen_test {
   my $want = shift; my $r = eval { $prog->ipc->popen( @_ ) };

   $EVAL_ERROR    and return $EVAL_ERROR;
   $want eq 'err' and return $r->stderr;
   $want eq 'out' and return $r->out;
   $want eq 'rv'  and return $r->rv;
   return $r;
}

my $cmd = "${perl} -v"; my $r;

like popen_test( 'out', $cmd ), qr{ larry \s+ wall }imsx,
   'popen captures stdout';

$cmd = "${perl} -e \"exit 2\""; $r = popen_test( 'out', $cmd );

is ref $r, EXCEPTION_CLASS, 'popen exception is right class';

like $r, qr{ Unknown \s+ error }msx, 'popen default error string';

is popen_test( 'rv', $cmd, { expected_rv => 2 } ), 2, 'popen expected rv';

$cmd = "${perl} -e \"die q(In a pit of fire)\"";

like popen_test( 'out', $cmd ), qr{ pit \s+ of \s+ fire }msx,
   'popen expected error string';

SKIP: {
   $osname eq 'mswin32' and skip 'popen capture stdin - not on MSWin32', 1;
   $cmd = "${perl} -e \"print <>\"";

   is popen_test( 'out', $cmd, { in => [ 'some text' ] } ), 'some text',
      'popen captures stdin and stdout';
}

$cmd = "${perl} -e\"warn 'danger'\"";

like popen_test( 'err', $cmd ), qr{ \A danger }mx, 'popen captures stderr';

$cmd = "${perl} -e\"sleep 5\"";

is popen_test( q(), $cmd, { timeout => 1 } )->class, 'TimeOut', 'popen timeout';

SKIP: {
   $ENV{AUTHOR_TESTING} or skip 'Proc::ProcessTable to flakey to test', 1;
   eval { require Proc::ProcessTable };
   $EVAL_ERROR and skip 'Proc::ProcessTable not installed', 1;

   is $prog->ipc->process_exists( pid => $PID ), 1, 'process exists';

   my @pids = $prog->ipc->child_list( $PID );

   is $pids[ 0 ], $PID, 'child list - first pid';
   is scalar @pids, 3, 'child list - proc count';

   my $table = $prog->ipc->process_table;

   ok $table->count > 0, 'process table';
}

sub run_cmd_test {
   my $want = shift; my $r = eval { $prog->run_cmd( @_ ) };

   $EVAL_ERROR    and return $EVAL_ERROR;
   $want eq 'out' and return $r->out;
   $want eq 'rv'  and return $r->rv;
   return $r;
}

SKIP: {
   $osname eq 'mswin32' and skip 'run_cmd system test - not on MSWin32', 5;

   $cmd = "${perl} -v"; $r = run_cmd_test( 'out', $cmd, { use_system => 1 } );

   like $r, qr{ larry \s+ wall }imsx, 'run_cmd system';

   $cmd = "${perl} -e \"exit 2\"";
   $r   = run_cmd_test( q(), $cmd, { use_system => 1 } );

   is ref $r, EXCEPTION_CLASS, 'run_cmd system exception is right class';

   like $r, qr{ Unknown \s+ error }msx, 'run_cmd system default error string';

   is run_cmd_test( 'rv', $cmd, { expected_rv => 2, use_system => 1 } ), 2,
      'run_cmd system expected rv';

   like run_cmd_test( 'out', $cmd, { async => 1 } ), qr{ background }msx,
      'run_cmd system async';

   $cmd = "${perl} -e \"sleep 5\"";

   is run_cmd_test( q(), $cmd, { timeout => 1, use_system => 1 } )->class,
      'TimeOut', 'run_cmd system timeout';
}

SKIP: {
   $osname eq 'mswin32' and skip 'run_cmd IPC::Run test - not on MSWin32', 6;

   eval { require IPC::Run }; $EVAL_ERROR
      and skip 'IPC::Run test - not installed', 6;

   $cmd = [ $perl, '-v' ];

   like run_cmd_test( 'out', $cmd ), qr{ larry \s+ wall }imsx,
      'run_cmd IPC::Run';

   $cmd = [ $perl, '-e', 'exit 1' ];

   like run_cmd_test( q(), $cmd ), qr{ Unknown \s+ error }msx,
      'run_cmd IPC::Run default error string';

   is run_cmd_test( 'rv', $cmd, { expected_rv => 1 } ), 1,
      'run_cmd IPC::Run expected rv';

   $cmd = [ $perl, '-v' ];

   like run_cmd_test( 'out', $cmd, { async => 1 } ), qr{ background }msx,
      'run_cmd IPC::Run async';

   $cmd = [ sub { print 'Hello World' } ];

   like run_cmd_test( 'out', $cmd, { async => 1 } ), qr{ background }msx,
      'run_cmd IPC::Run async coderef';

   unlike run_cmd_test( 'rv', $cmd, { async => 1 } ), qr{ \(-1\) }msx,
      'run_cmd IPC::Run async coderef captures pid';

   $cmd = [ $perl, '-e', 'sleep 5' ];

   is run_cmd_test( q(), $cmd, { timeout => 1 } )->class, 'TimeOut',
      'run_cmd IPC::Run timeout';
}

# This fails on some platforms. The stderr is not redirected as expected
#eval { $prog->run_cmd( "unknown_command_xa23sd3", { debug => 1 } ) };

#ok $EVAL_ERROR =~ m{ unknown_command }mx, 'unknown command';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
