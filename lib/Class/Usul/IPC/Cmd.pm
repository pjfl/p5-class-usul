package Class::Usul::IPC::Cmd;

use namespace::autoclean;

use Moo;
use Class::Null;
use Class::Usul::Constants    qw( EXCEPTION_CLASS FALSE NUL OK SPC TRUE );
use Class::Usul::Functions    qw( arg_list emit_to io is_arrayref
                                  is_coderef is_member is_win32
                                  merge_attributes nonblocking_write_pipe_pair
                                  strip_leader throw );
use Class::Usul::Time         qw( nap );
use Class::Usul::Types        qw( ArrayRef Bool LoadableClass LogType
                                  NonEmptySimpleStr Num Object PositiveInt
                                  SimpleStr Str Undef );
use English                   qw( -no_match_vars );
use File::Basename            qw( basename );
use File::DataClass::Types    qw( Directory Path );
use File::Spec::Functions     qw( devnull rootdir tmpdir );
use IO::Handle;
use IO::Select;
use IPC::Open3;
use Module::Load::Conditional qw( can_load );
use POSIX                     qw( _exit setsid sysconf WIFEXITED WNOHANG );
use Scalar::Util              qw( blessed openhandle );
use Socket                    qw( AF_UNIX SOCK_STREAM PF_UNSPEC );
use Try::Tiny;
use Unexpected::Functions     qw( TimeOut Unspecified );

our ($CHILD_ENUM, $CHILD_PID);

# Public attributes
has 'async'           => is => 'ro',   isa => Bool, default => FALSE;

has 'close_all_files' => is => 'ro',   isa => Bool, default => FALSE;

has 'cmd'             => is => 'ro',   isa => ArrayRef | NonEmptySimpleStr,
   required           => TRUE;

has 'detach'          => is => 'ro',   isa => Bool, default => FALSE;

has 'err'             => is => 'ro',   isa => Path | SimpleStr, default => NUL;

has 'expected_rv'     => is => 'ro',   isa => PositiveInt, default => 0;

has 'ignore_zombies'  => is => 'ro',   isa => Bool, default => FALSE;

has 'in'              => is => 'ro',   isa => Path | SimpleStr,
   coerce             => sub { __arrayref2str( $_[ 0 ] ) },
   default            => NUL;

has 'is_daemon'       => is => 'rwp',  isa => Bool, default => FALSE;

has 'log'             => is => 'ro',   isa => LogType,
   builder            => sub { Class::Null->new };

has 'keep_fds'        => is => 'ro',   isa => ArrayRef, builder => sub { [] };

has 'max_daemon_wait' => is => 'ro',   isa => PositiveInt, default => 15;

has 'nap_time'        => is => 'ro',   isa => Num, default => 0.3;

has 'out'             => is => 'ro',   isa => Path | SimpleStr, default => NUL;

has 'pidfile'         => is => 'lazy', isa => Path,
   builder            => sub { $_[ 0 ]->_tempfile },
   coerce             => Path->coercion;

has 'response_class'  => is => 'lazy', isa => LoadableClass,
   default            => 'Class::Usul::Response::IPC',
   coerce             => LoadableClass->coercion;

has 'tempdir'         => is => 'ro',   isa => Directory,
   builder            => sub { tmpdir }, coerce => Directory->coercion;

has 'timeout'         => is => 'ro',   isa => PositiveInt, default => 0;

has 'use_ipc_run'     => is => 'ro',   isa => Bool, default => FALSE;

has 'use_system'      => is => 'ro',   isa => Bool, default => FALSE;

has 'working_dir'     => is => 'lazy', isa => Directory | Undef,
   default            => undef;

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   my $builder = delete $attr->{builder} or return $attr;

   merge_attributes $attr, $builder,         {}, [ 'log' ];
   merge_attributes $attr, $builder->config, {}, [ 'tempdir' ];
   return $attr;
};

sub BUILD {
   $_[ 0 ]->pidfile->chomp->lock; return;
}

# Public methods
sub run_cmd {
   return blessed $_[ 0 ] ? $_[ 0 ]->_run_cmd : __PACKAGE__->new( @_ )->_run_cmd
}

# Private methods
sub _daemonise { # Returns false to the parent true to the child
   $_[ 0 ]->_fork_process; return $_[ 0 ]->_detach_process;
}

sub _detach_process {
   my $self = shift; $self->is_daemon or return FALSE; # Return if parent ...

   # Now we are the child ...
   setsid or throw 'Cannot detach from controlling process';
   $SIG{HUP} = 'IGNORE'; fork and _exit OK; chdir rootdir;
#  Clearing file creation mask allows direct control of the access mode of
#  created files and directories in open, mkdir, and mkpath functions
   umask 0;

   if ($self->close_all_files) { # Close all fds except the ones we should keep
      my $openmax = sysconf( &POSIX::_SC_OPEN_MAX );

      (not defined $openmax or $openmax < 0) and $openmax = 64;

      for (grep { not is_member $_, $self->keep_fds } 0 .. $openmax) {
         POSIX::close( $_ );
      }
   }

   return TRUE;
}

sub _fork_process { # Returns pid to the parent undef to the child
   my $self = shift; $self->ignore_zombies and $SIG{CHLD} = 'IGNORE';

   my $pid; $pid = fork and return $pid; $self->_set_is_daemon( TRUE );

   return;
}

sub _ipc_run_harness {
   my ($self, $cmd_ref, @cmd_args) = @_;

   if ($self->async) {
      my $pidfile = $self->pidfile;

      is_coderef $cmd_ref->[ 0 ] and $cmd_ref = $cmd_ref->[ 0 ];

      my $h = IPC::Run::harness( $cmd_ref, @cmd_args, init => sub {
         $pidfile->println( $PID )->close }, '&' );

      $h->start; return ( 0, $h );
   }

   my $h  = IPC::Run::harness( $cmd_ref, @cmd_args ); $h->run;
   my $rv = $h->full_result || 0; $rv =~ m{ unknown }msx and throw $rv;

   return ( $rv, $h );
}

sub _remove_pid {
   return $_[ 0 ]->pidfile->exists ? $_[ 0 ]->pidfile->unlink : FALSE;
}

sub _return_codes_or_throw {
   my ($self, $cmd, $e_num, $e_str) = @_;

   $e_str ||= 'Unknown error'; chomp $e_str;

   if ($e_num == -1) {
      my $error = 'Program [_1] failed to start: [_2]';
      my $prog  = basename( (split SPC, $cmd)[ 0 ] );

      throw $error, args => [ $prog, $e_str ], level => 3, rv => -1;
   }

   my $rv = $e_num >> 8; my $core = $e_num & 128; my $sig = $e_num & 127;

   if ($rv > $self->expected_rv) {
      $self->log->debug( my $error = "${e_str} rv ${rv}" );
      throw $error, level => 3, rv => $rv;
   }

   return { core => $core, rv => $rv, sig => $sig, };
}

sub _run_cmd {
   my $self = shift; my $cmd = $self->cmd;

   if (is_arrayref $cmd) {
      $cmd->[ 0 ] or throw Unspecified, args => [ 'command' ];

      unless (is_win32) {
         not $self->use_ipc_run and return $self->_run_cmd_using_fork_and_exec;

         $self->use_ipc_run and can_load( modules => { 'IPC::Run' => '0.84' } )
            and return $self->_run_cmd_using_ipc_run;
      }

      $cmd = join SPC, @{ $cmd };
   }

   not is_win32 and ($self->async or $self->use_system)
      and return $self->_run_cmd_using_system( $cmd );

   # Open3 does not return the exit code of the child
   return $self->_run_cmd_using_open3( $cmd );
}

sub _run_cmd_using_fork_and_exec {
   my $self = shift; my $cmd = $self->cmd->[ 0 ];

   my $in_h  = nonblocking_write_pipe_pair;
   my $out_h = nonblocking_write_pipe_pair;
   my $err_h = nonblocking_write_pipe_pair;

   if ($self->detach) {
      my $pidfile = $self->pidfile;

      unless ($self->_daemonise) { # Parent
         my $waited = 0;

         while (not $pidfile->exists or not $pidfile->is_empty) {
            nap $self->nap_time; $waited += $self->nap_time;
            $waited > $self->max_daemon_wait
               and throw 'File [_1] contains no process id';
         }

         return $self->response_class->new( pid => $pidfile->getline );
      }

      $pidfile->println( $PID ); # Child
   }
   elsif (my $pid = $self->_fork_process) { # Parent
      $in_h = $in_h->[ 1 ]; $out_h = $out_h->[ 0 ]; $err_h = $err_h->[ 0 ];

      my $prog = basename( $cmd );

      if ($self->async) {
         my $out = "Started ${prog}(${pid}) in the background";

         return $self->response_class->new( out => $out, pid => $pid );
      }

      my ($fltout, $stderr, $stdout) = (NUL, NUL, NUL); my (%hands, @ready);

      my $err = $self->err; my $errhand = sub {
         my $buf = shift; defined $buf or return;

         $err eq 'out'    and $fltout .= $buf;
         $err ne 'null'   and $stderr .= $buf;
         $err eq 'stderr' and emit_to \*STDERR, $buf;
         return;
      };

      my $out = $self->out; my $outhand = sub {
         my $buf = shift; defined $buf or return; $fltout .= $buf;

         $out ne 'null'   and $stdout .= $buf;
         $out eq 'stdout' and emit_to \*STDOUT, $buf;
         return;
      };

      try {
         my $tmout = $self->timeout; $tmout and local $SIG{ALRM} = sub {
            throw TimeOut, args => [ $prog, $tmout ];
         };
         alarm $tmout;

         if (blessed $self->in) { emit_to $in_h, $self->in->slurp }
         elsif ($self->in ne 'null' and $self->in ne 'stdin') {
            emit_to $in_h, $self->in;
         }

         close $in_h;

         my $selector = IO::Select->new(); $selector->add( $err_h, $out_h );

         $hands{ fileno $err_h } = $errhand; $hands{ fileno $out_h } = $outhand;

         while (@ready = $selector->can_read) {
            for my $fh (@ready) {
               my $buf; my $bytes_read = sysread( $fh, $buf, 64 * 1024 );

               if ($bytes_read) { $hands{ fileno $fh }->( "${buf}" ) }
               else { $selector->remove( $fh ); close $fh }
            }
         }

         waitpid $pid, 0;
         alarm 0;
      }
      catch { throw $_ };

      my $codes = $self->_return_codes_or_throw( $cmd, $CHILD_ERROR, $stderr );

      return $self->response_class->new
         (  core   => $codes->{core}, out    => __filter_out( $fltout ),
            rv     => $codes->{rv},   sig    => $codes->{sig},
            stderr => $stderr,        stdout => $stdout );
   }

   # Child
   __redirect_stdin (  $in_h->[ 0 ] );
   __redirect_stdout( $out_h->[ 1 ] );
   __redirect_stderr( $err_h->[ 1 ] );

   $self->working_dir and chdir $self->working_dir;

   unless (is_coderef $cmd) {
      exec @{ $self->cmd }
         or throw 'Command [_1] failed to execute: [_2]',
            args => [ $cmd, $OS_ERROR ];
   }

   $self->_setup_signals; my (undef, @args) = @{ $self->cmd };

   my $rv = $cmd->( $self, @args ); $rv = $rv << 8; $self->_remove_pid;

   _exit $rv;
}

sub _run_cmd_using_ipc_run {
   my $self = shift; my ($buf_err, $buf_out, $error, $h, $rv);

   my $cmd_ref  = __partition_command( my $cmd = $self->cmd );
   my $cmd_str  = join SPC, @{ $cmd }; $self->async and $cmd_str .= ' &';
   my $prog     = basename( $cmd->[ 0 ] );
   my $null     = devnull;
   my $in       = $self->in;
   my $out      = $self->out;
   my $err      = $self->err;
   my @cmd_args = ();

   if    (blessed $in)      { push @cmd_args, "0<${in}"       }
   elsif ($in  eq 'null')   { push @cmd_args, "0<${null}"     }
   elsif ($in  ne 'stdin')  { push @cmd_args, '0<', \$in      }

   if    (blessed $out)     { push @cmd_args, "1>${out}"      }
   elsif ($out eq 'null')   { push @cmd_args, "1>${null}"     }
   elsif ($out ne 'stdout') { push @cmd_args, '1>', \$buf_out }

   if    (blessed $err)     { push @cmd_args, "2>${err}"      }
   elsif ($err eq 'out')    { push @cmd_args, '2>&1'          }
   elsif ($err eq 'null')   { push @cmd_args, "2>${null}"     }
   elsif ($err ne 'stderr') { push @cmd_args, '2>', \$buf_err }

   $self->log->debug( "Running ${cmd_str}" );

   try {
      my $tmout = $self->timeout; $tmout and local $SIG{ALRM} = sub {
         throw TimeOut, args => [ $cmd_str, $tmout ];
      };
      alarm $tmout;
      ($rv, $h) = $self->_ipc_run_harness( $cmd_ref, @cmd_args );
      alarm 0;
   }
   catch { throw $_ };

   $self->log->debug( "Run harness returned ${rv}" );

   my $sig = $rv & 127; my $core = $rv & 128; $rv = $rv >> 8;

   if ($self->async) {
      my $pid = $self->pidfile->getline || -1; $self->pidfile->close;

      $out = "Started ${prog}(${pid}) in the background";

      return $self->response_class->new
         ( core => $core, harness => $h,  out => $out,
           pid  => $pid,  rv      => $rv, sig => $sig );
   }

   my ($stderr, $stdout) = (NUL, NUL);

   if ($out ne 'null' and $out ne 'stdout') {
       not blessed $out and $out = __filter_out( $stdout = $buf_out );
   }
   else { $out = $stdout = NUL }

   if    ($err eq 'out') { $stderr = $stdout; $error = $out; chomp $error }
   elsif (blessed $err)  { $stderr = $error = $err->all; chomp $error }
   elsif ($err ne 'null' and $err ne 'stderr') {
      $stderr = $error = $buf_err; chomp $error;
   }
   else { $stderr = $error = NUL }

   if ($rv > $self->expected_rv) {
      $error = $error ? "${error} rv ${rv}" : "Unknown error rv ${rv}";
      $self->log->debug( $error );
      throw $error, out => $out, rv => $rv;
   }

   return $self->response_class->new
      (  core => $core, out    => "${out}", rv     => $rv,
         sig  => $sig,  stderr => $stderr,  stdout => $stdout );
}

sub _run_cmd_using_open3 { # Robbed in part from IPC::Cmd
   my ($self, $cmd) = @_; my ($fltout, $stderr, $stdout) = (NUL, NUL, NUL);

   my $err = $self->err; my $errhand = sub {
      my $buf = shift; defined $buf or return;

      $err eq 'out'    and $fltout .= $buf;
      $err ne 'null'   and $stderr .= $buf;
      $err eq 'stderr' and emit_to \*STDERR, $buf;
      return;
   };
   my $out = $self->out; my $outhand = sub {
      my $buf = shift; defined $buf or return; $fltout .= $buf;

      $out ne 'null'   and $stdout .= $buf;
      $out eq 'stdout' and emit_to \*STDOUT, $buf;
      return;
   };
   my $pipe = sub {
      socketpair( $_[ 0 ], $_[ 1 ], AF_UNIX, SOCK_STREAM, PF_UNSPEC ) or return;
      shutdown  ( $_[ 0 ], 1 );  # No more writing for reader
      shutdown  ( $_[ 1 ], 0 );  # No more reading for writer
      return TRUE;
   };
   my $open3 = sub {
      local (*TO_CHLD_R,     *TO_CHLD_W);
      local (*FR_CHLD_R,     *FR_CHLD_W);
      local (*FR_CHLD_ERR_R, *FR_CHLD_ERR_W);

      $pipe->( *TO_CHLD_R,     *TO_CHLD_W     ) or throw $EXTENDED_OS_ERROR;
      $pipe->( *FR_CHLD_R,     *FR_CHLD_W     ) or throw $EXTENDED_OS_ERROR;
      $pipe->( *FR_CHLD_ERR_R, *FR_CHLD_ERR_W ) or throw $EXTENDED_OS_ERROR;

      my $pid = open3( '>&TO_CHLD_R', '<&FR_CHLD_W', '<&FR_CHLD_ERR_W', @_ );

      return ($pid, *TO_CHLD_W, *FR_CHLD_R, *FR_CHLD_ERR_R);
   };

   local ($CHILD_ENUM, $CHILD_PID) = ( 0, 0 );

   my ($err_h, %hands, $in_h, $out_h, $pid, @ready);

   $self->log->debug( "Running ${cmd}" );

   try {
      local $SIG{PIPE} = \&__pipe_handler;
      my $tmout = $self->timeout; $tmout and local $SIG{ALRM} = sub {
         throw TimeOut, args => [ $cmd, $tmout ];
      };
      alarm $tmout;
      ($pid, $in_h, $out_h, $err_h) = $open3->( $cmd );

      if (blessed $self->in) { emit_to $in_h, $self->in->slurp }
      elsif ($self->in ne 'null' and $self->in ne 'stdin') {
         emit_to $in_h, $self->in;
      }

      close $in_h;

      my $selector = IO::Select->new(); $selector->add( $err_h, $out_h );

      $hands{ fileno $err_h } = $errhand; $hands{ fileno $out_h } = $outhand;

      while (@ready = $selector->can_read) {
         for my $fh (@ready) {
            my $buf; my $bytes_read = sysread( $fh, $buf, 64 * 1024 );

            if ($bytes_read) { $hands{ fileno $fh }->( "${buf}" ) }
            else { $selector->remove( $fh ); close $fh }
         }
      }

      $pid and waitpid $pid, 0;
      alarm 0;
   }
   catch { throw $_ };

   my $e_num = $CHILD_PID > 0 ? $CHILD_ENUM : $CHILD_ERROR;
   my $codes = $self->_return_codes_or_throw( $cmd, $e_num, $stderr );

   return $self->response_class->new
      (  core   => $codes->{core}, out    => __filter_out( $fltout ),
         rv     => $codes->{rv},   sig    => $codes->{sig},
         stderr => $stderr,        stdout => $stdout );
}

sub _run_cmd_using_system {
   my ($self, $cmd) = @_; my ($error, $rv);

   my $prog = basename( (split SPC, $cmd)[ 0 ] ); my $null = devnull;

   my $in   = $self->in; my $out = $self->out; my $err = $self->err;

   if ($in ne 'null' and $in ne 'stdin' and not blessed $in) {
      # Different semi-random file names in the temp directory
      my $tmp = $self->_tempfile; $tmp->print( $in ); $in = $tmp;
   }

   $out ne 'null' and $out ne 'stdout' and not blessed $out
      and $out = $self->_tempfile;
   $self->async and $err ||= 'out';
   $err ne 'null' and $err ne 'stderr' and not blessed $err and $err ne 'out'
      and $err = $self->_tempfile;

   $cmd .= $in  eq 'stdin'  ? NUL : $in  eq 'null' ? " 0<${null}" : " 0<${in}";
   $cmd .= $out eq 'stdout' ? NUL : $out eq 'null' ? " 1>${null}" : " 1>${out}";
   $cmd .= $err eq 'stderr' ? NUL : $err eq 'null' ? " 2>${null}"
                                  : $err ne 'out'  ? " 2>${err}"  : ' 2>&1';

   $self->async and $cmd .= ' & echo $! 1>'.$self->pidfile->pathname;
   $self->log->debug( "Running ${cmd}" );

   {  local ($CHILD_ENUM, $CHILD_PID) = (0, 0);

      try {
         local $SIG{CHLD} = \&__child_handler;

         my $tmout = $self->timeout; $tmout and local $SIG{ALRM} = sub {
            throw TimeOut, args => [ $cmd, $tmout ];
         };

         alarm $tmout; $rv = system $cmd; alarm 0;
      }
      catch { throw $_ };

      my $os_error = $OS_ERROR;

      $self->log->debug
         ( "System rv ${rv} child pid ${CHILD_PID} error ${CHILD_ENUM}" );
      # On some systems the child handler reaps the child process so the system
      # call returns -1 and sets $OS_ERROR to 'No child processes'. This line
      # and the child handler code fix the problem
      $rv == -1 and $CHILD_PID > 0 and $rv = $CHILD_ENUM;
      $rv == -1 and throw 'Program [_1] failed to start: [_2]',
                          args => [ $prog, $os_error ], rv => $rv;
   }

   my $sig = $rv & 127; my $core = $rv & 128; $rv = $rv >> 8;

   my ($stderr, $stdout) = (NUL, NUL);

   if ($self->async) {
      $rv != 0 and throw 'Program [_1] failed to start',
                         args => [ $prog ], rv => $rv;

      my $pid = $self->pidfile->getline || -1; $self->pidfile->close;

      $out = "Started ${prog}(${pid}) in the background";

      return $self->response_class->new
         (  core => $core, out => $out, pid => $pid, rv => $rv, sig => $sig );
   }

   if ($out ne 'stdout' and $out ne 'null' and -f $out) {
      $out = __filter_out( $stdout = io( $out )->slurp );
   }
   else { $out = $stdout = NUL }

   if ($err eq 'out') { $stderr = $stdout; $error = $out; chomp $error }
   elsif ($err ne 'stderr' and $err ne 'null' and -f $err) {
      $stderr = $error = io( $err )->slurp; chomp $error;
   }
   else { $stderr = $error = NUL }

   if ($rv > $self->expected_rv) {
      $error = $error ? "${error} rv ${rv}" : "Unknown error rv ${rv}";
      $self->log->debug( $error );
      throw $error, out => $out, rv => $rv;
   }

   return $self->response_class->new
      (  core => $core, out    => "${out}", rv     => $rv,
         sig  => $sig,  stderr => $stderr,  stdout => $stdout );
}

sub _setup_signals {
   my $self = shift; $SIG{INT} = sub { $self->_shutdown };
}

sub _shutdown {
   my $self = shift; my $pidfile = $self->pidfile;

   $pidfile->exists and $pidfile->getline == $PID and $self->_remove_pid;

   exit OK;
}

sub _tempfile {
   return io( $_[ 0 ]->tempdir )->tempfile;
}

# Private functions
sub __arrayref2str {
   return (is_arrayref $_[ 0 ]) ? join $RS, @{ $_[ 0 ] } : $_[ 0 ];
}

sub __child_handler {
   local $OS_ERROR; # So that waitpid does not step on existing value

   while ((my $child_pid = waitpid -1, WNOHANG) > 0) {
      if (WIFEXITED( $CHILD_ERROR ) and $child_pid > ($CHILD_PID || 0)) {
         $CHILD_PID = $child_pid; $CHILD_ENUM = $CHILD_ERROR;
      }
   }

   $SIG{CHLD} = \&__child_handler; # In case of unreliable signals
   return;
}

sub __filter_out {
   return join "\n", map    { strip_leader $_ }
                     grep   { not m{ (?: Started | Finished ) }msx }
                     split m{ [\n] }msx, $_[ 0 ];
}

sub __partition_command {
   my $cmd = shift; my $aref = []; my @command = ();

   for my $item (grep { defined && length } @{ $cmd }) {
      if ($item !~ m{ [^\\][\<\>\|\&] }mx) { push @{ $aref }, $item }
      else { push @command, $aref, $item; $aref = [] }
   }

   if ($aref->[ 0 ]) {
      if ($command[ 0 ]) { push @command, $aref }
      else { @command = @{ $aref } }
   }

   return \@command;
}

sub __pipe_handler {
   local $OS_ERROR; # So that wait does not step on existing value

   $CHILD_PID = wait; $CHILD_ENUM = (255 << 8) + 13;
   $SIG{PIPE} = \&__pipe_handler;
   return;
}

sub __redirect_stderr {
   my $v  = shift; my $err = \*STDERR; close $err;

   my $op = openhandle $v ? '>&' : '>'; my $sink = $op eq '>' ? $v : fileno $v;

   open $err, $op, $sink or throw "Could not redirect STDERR: ${OS_ERROR}";
   return;
}

sub __redirect_stdin {
   my $v  = shift; my $in = \*STDIN; close $in;

   my $op = openhandle $v ? '<&' : '<'; my $src = $op eq '<' ? $v : fileno $v;

   open $in,  $op, $src  or throw "Could not redirect STDIN: ${OS_ERROR}";
   return;
}

sub __redirect_stdout {
   my $v  = shift; my $out = \*STDOUT; close $out;

   my $op = openhandle $v ? '>&' : '>'; my $sink = $op eq '>' ? $v : fileno $v;

   open $out, $op, $sink or throw "Could not redirect STDOUT: ${OS_ERROR}";
   return;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Class::Usul::TraitFor::Daemonise - One-line description of the modules purpose

=head1 Synopsis

   use Class::Usul::TraitFor::Daemonise;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<async>

=item C<close_all_files>

=item C<cmd>

=item C<detach>

=item C<err>

=item C<expected_rv>

=item C<ignore_zombies>

=item C<in>

=item C<is_daemon>

=item C<keep_fds>

=item C<log>

=item C<max_daemon_wait>

=item C<nap_time>

=item C<out>

=item C<run_cmd>

=item C<tempdir>

=item C<timeout>

=item C<use_ipc_run>

=item C<use_system>

=back

=head1 Subroutines/Methods

=head2 C<BUILD>

=head2 C<BUILDARGS>

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Usul.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2014 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
