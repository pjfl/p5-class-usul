use t::boilerplate;

use Test::More;
use File::Spec::Functions qw( catdir catfile tmpdir );
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
use Class::Usul::Functions qw( io );

my $osname = lc $OSNAME;
my $perl   = $EXECUTABLE_NAME;
my $prog   = Class::Usul::Programs->new( appclass => 'Class::Usul',
                                         config   => { cache_ttys => 0,
                                                       logsdir    => 't',
                                                       rundir     => 't',
                                                       tempdir    => 't', },
                                         log      => Logger->new,
                                         method   => 'dump_self',
                                         noask    => 1,
                                         quiet    => 1, );

SKIP: {
   $ENV{AUTHOR_TESTING} or skip 'Proc::ProcessTable to flakey to test', 1;
   eval { require Proc::ProcessTable };
   $EVAL_ERROR and skip 'Proc::ProcessTable not installed', 1;

   is $prog->ipc->process_exists( pid => $PID ), 1, 'process exists';

   my @pids = $prog->ipc->child_list( $PID );

   is $pids[ 0 ], $PID, 'child list - first pid';

   my $table = $prog->ipc->process_table;

   ok $table->{count} > 0, 'process table';
}

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
   'popen - captures stdout';

$cmd = "${perl} -e \"exit 2\""; $r = popen_test( 'out', $cmd );

is ref $r, EXCEPTION_CLASS, 'popen - exception is right class';

like $r, qr{ Unknown \s+ error }msx, 'popen - default error string';

is popen_test( 'rv', $cmd, { expected_rv => 2 } ), 2, 'popen - expected rv';

$cmd = "${perl} -e \"die q(In a pit of fire)\"";

like popen_test( 'out', $cmd ), qr{ pit \s+ of \s+ fire }msx,
   'popen - expected error string';

$cmd = "${perl} -e\"warn 'danger'\"";

like popen_test( 'err', $cmd ), qr{ \A danger }mx, 'popen - captures stderr';

$cmd = "${perl} -e\"sleep 5\"";

is popen_test( q(), $cmd, { timeout => 1 } )->class, 'TimeOut',
   'popen - timeout';

SKIP: {
   $osname eq 'mswin32' and skip 'popen capture stdin - not on MSWin32', 1;
   $cmd = "${perl} -e 'print <>'";

   is popen_test( 'out', $cmd, { in => [ 'some text' ] } ), 'some text',
      'popen - captures stdin';
}

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
