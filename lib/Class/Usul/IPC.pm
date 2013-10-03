# @(#)$Ident: IPC.pm 2013-10-03 13:17 pjf ;

package Class::Usul::IPC;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.30.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Null;
use Class::Usul::Constants;
use Class::Usul::File;
use Class::Usul::Functions    qw( arg_list emit_to get_user is_arrayref
                                  is_coderef is_win32 loginid merge_attributes
                                  strip_leader throw );
use Class::Usul::Time         qw( time2str );
use Class::Usul::Types        qw( BaseType FileType LoadableClass );
use English                   qw( -no_match_vars );
use File::Basename            qw( basename );
use File::Spec;
use IO::Handle;
use IO::Select;
use IPC::Open3;
use Module::Load::Conditional qw( can_load );
use Moo;
use POSIX                     qw( WIFEXITED WNOHANG );
use Scalar::Util              qw( blessed );
use Socket                    qw( AF_UNIX SOCK_STREAM PF_UNSPEC );
use Try::Tiny;

our ($CHILD_ENUM, $CHILD_PID);

# Public attributes
has 'response_class' => is => 'lazy', isa => LoadableClass,
   default           => 'Class::Usul::Response::IPC',
   coerce            => LoadableClass->coercion;

has 'table_class'    => is => 'lazy', isa => LoadableClass,
   default           => 'Class::Usul::Response::Table',
   coerce            => LoadableClass->coercion;

# Private attributes
has '_file' => is => 'lazy', isa => FileType,
   default  => sub { Class::Usul::File->new( builder => $_[ 0 ]->_usul ) },
   handles  => [ qw( io tempdir tempfile ) ], init_arg => undef;

has '_usul' => is => 'ro',   isa => BaseType,
   handles  => [ qw( config debug lock log ) ], init_arg => 'builder',
   required => TRUE, weak_ref => TRUE;

# Public methods
sub child_list {
   my ($self, $pid, $procs) = @_; my ($child, $ppt); my @pids = ();

   unless (defined $procs) {
      $ppt   = __new_proc_process_table();
      $procs = { map { $_->pid => $_->ppid } @{ $ppt->table } };
   }

   if (exists $procs->{ $pid }) {
      for $child (grep { $procs->{ $_ } == $pid } keys %{ $procs }) {
         push @pids, $self->child_list( $child, $procs ); # Recurse
      }

      push @pids, $pid;
   }

   return @pids;
}

sub popen { # Robbed from IPC::Cmd
   my ($self, $cmd, @opts) = @_; $cmd or throw 'Run command not specified';

   is_arrayref $cmd and $cmd = join SPC, @{ $cmd };

   my $opts = $self->_default_run_options( @opts );

   $opts->{err} ||= NUL; $opts->{out} ||= NUL;

   my ($out, $stderr, $stdout) = (NUL, NUL, NUL);

   my $errhand = sub {
      my $buf = shift; defined $buf or return;

      $opts->{err} ne 'null'   and $stderr .= $buf;
      $opts->{err} eq 'out'    and $out .= $buf;
      $opts->{err} eq 'stderr' and emit_to( \*STDERR, $buf );
      return;
   };
   my $outhand = sub {
      my $buf = shift; defined $buf or return; $out .= $buf;

      $opts->{out} ne 'null'   and $stdout .= $buf;
      $opts->{out} eq 'stdout' and emit_to( \*STDOUT, $buf );
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

   $opts->{debug} and $self->log->debug( "Running ${cmd}" );

   try {
      local $SIG{PIPE} = \&__cleaner;

      ($pid, $in_h, $out_h, $err_h) = $open3->( $cmd );
      $opts->{in} ne 'stdin' and emit_to( $in_h, $opts->{in} );
      close $in_h;
   }
   catch { throw $_ };

   my $selector = IO::Select->new(); $selector->add( $err_h, $out_h );

   $hands{ fileno $err_h } = $errhand; $hands{ fileno $out_h } = $outhand;

   while (@ready = $selector->can_read) {
      for my $fh (@ready) {
         my $buf; my $bytes_read = sysread( $fh, $buf, 64 * 1024 );

         if ($bytes_read) { $hands{ fileno $fh }->( "${buf}" ) }
         else { $selector->remove( $fh ); close $fh }
      }
   }

   waitpid $pid, 0; my $e_num = $CHILD_PID > 0 ? $CHILD_ENUM : $CHILD_ERROR;

   my $codes = $self->_return_codes_or_throw( $cmd, $opts, $e_num, $stderr );

   return $self->response_class->new( core   => $codes->{core},
                                      out    => __run_cmd_filter_out( $out ),
                                      rv     => $codes->{rv},
                                      sig    => $codes->{sig},
                                      stderr => $stderr,
                                      stdout => $stdout );
}

sub process_exists {
   my ($self, @args) = @_; my $args = arg_list @args;

   my $pid = $args->{pid}; my ($io, $file);

   $file = $args->{file} and $io = $self->io( $file ) and $io->is_file
      and $pid = $io->chomp->lock->getline;

   (not $pid or $pid !~ m{ \d+ }mx) and return FALSE;

   return (CORE::kill 0, $pid) ? TRUE : FALSE;
}

sub process_table {
   my ($self, @args) = @_; my $args = arg_list @args;

   my $pat   = $args->{pattern};
   my $ptype = $args->{type   } // 1;
   my $user  = $args->{user   } // get_user->name;
   my $ppt   = __new_proc_process_table();
   my $has   = { map { $_ => TRUE } $ppt->fields };
   my @rows  = ();
   my $count = 0;

   if ($ptype == 3) {
      my %procs = map { $_->pid => $_ } @{ $ppt->table };
      my @pids  = $self->_list_pids_by_file_system( $args->{fsystem} );

      for my $p (grep { defined } map { $procs{ $_ } } @pids) {
         push @rows, $self->_set_fields( $has, $p );
         $count++;
      }
   }
   else {
      for my $p (@{ $ppt->table }) {
         if (   ($ptype == 1 and __proc_belongs_to_user( $p->uid, $user ))
             or ($ptype == 2 and __cmd_matches_pattern( $p->cmndline, $pat ))) {
            push @rows, $self->_set_fields( $has, $p );
            $count++;
         }
      }
   }

   return $self->_new_process_table( [ sort { __pscomp( $a, $b ) } @rows ],
                                     $count );
}

sub run_cmd {
   my ($self, $cmd, @opts) = @_; $cmd or throw 'Run command not specified';

   if (is_arrayref $cmd) {
      if (not is_win32 and can_load( modules => { 'IPC::Run' => '0.84' } )) {
         return $self->_run_cmd_using_ipc_run( $cmd, @opts );
      }

      $cmd = join SPC, @{ $cmd };
   }

   return is_win32 ? $self->popen( $cmd, @opts )
                   : $self->_run_cmd_using_system( $cmd, @opts );
}

sub signal_process {
   my ($self, $flag, $sig, $pids) = @_; my $opts = [];

   $sig  and push @{ $opts }, '-o', "sig=${sig}";
   $flag and push @{ $opts }, '-o', 'flag=one';

   my $cmd = [ $self->config->suid, qw( -nc signal_process ),
               @{ $opts }, '--', @{ $pids || [] } ];

   return $self->run_cmd( $cmd );
}

sub signal_process_as_root {
   my ($self, @args) = @_; my ($file, $io);

   my $args = arg_list @args;
   my $sig  = $args->{sig } || 'TERM';
   my $pids = $args->{pids} || [];

   $args->{pid} and push @{ $pids }, $args->{pid};

   if ($file = $args->{file}
       and $io = $self->io( $file ) and $io->is_file) {
      push @{ $pids }, $io->chomp->lock->getlines;
      $sig eq 'TERM' and unlink $file;
   }

   (defined $pids->[0] and $pids->[0] =~ m{ \d+ }mx) or throw 'Process id bad';

   for my $mpid (@{ $pids }) {
      if (exists $args->{flag} and $args->{flag} =~ m{ one }imx) {
         CORE::kill $sig, $mpid;
         next;
      }

      my @pids = reverse $self->child_list( $mpid );

      CORE::kill $sig, $_ for (@pids);

      $args->{force} or next;

      sleep 3; @pids = reverse $self->child_list( $mpid );

      CORE::kill 'KILL', $_ for (@pids);
   }

   return OK;
}

# Private methods
sub _default_run_options {
   my ($self, @opts) = @_; my $opts = arg_list @opts;

   is_arrayref $opts->{in} and $opts->{in} = join $RS, @{ $opts->{in} };

   $opts->{debug      } ||= $self->debug;
   $opts->{expected_rv} ||= 0;
   $opts->{in         } ||= 'stdin';
   $opts->{tempdir    } ||= $self->tempdir;
   $opts->{pid_ref    } ||= $self->tempfile( $opts->{tempdir} );
   return $opts;
}

sub _list_pids_by_file_system {
   my ($self, $fsystem) = @_; $fsystem or return ();

   my $opts = { err => 'null', expected_rv => 1 };
   # TODO: Make fuser OS dependent
   my $data = $self->run_cmd( "fuser ${fsystem}", $opts )->out || NUL;

   $data =~ s{ [^0-9\s] }{}gmx; $data =~ s{ \s+ }{ }gmx;

   return sort { $a <=> $b } grep { defined && length } split SPC, $data;
}

sub _new_process_table {
   my ($self, $rows, $count) = @_;

   return $self->table_class->new
      ( count    => $count,
        fields   => [ qw( uid pid ppid start time size state tty cmd ) ],
        labels   => { uid   => 'User',   pid   => 'PID',
                      ppid  => 'PPID',   start => 'Start Time',
                      tty   => 'TTY',    time  => 'Time',
                      size  => 'Size',   state => 'State',
                      cmd   => 'Command' },
        typelist => { pid   => 'numeric', ppid => 'numeric',
                      start => 'date',    size => 'numeric',
                      time  => 'numeric' },
        values   => $rows,
        wrap     => { cmd => 1 }, );
}

sub _return_codes_or_throw {
   my ($self, $cmd, $opts, $e_num, $e_str) = @_;

   $e_str ||= 'Unknown error'; chomp $e_str;

   if ($e_num == -1) {
      my $error = 'Program [_1] failed to start: [_2]';
      my $prog  = basename( (split SPC, $cmd)[ 0 ] );

      throw error => $error, level => 3, args => [ $prog, $e_str ], rv => -1;
   }

   my $rv = $e_num >> 8; my $core = $e_num & 128; my $sig = $e_num & 127;

   if ($rv > $opts->{expected_rv}) {
      $opts->{debug} and $self->log->debug( "RV ${rv}: ${e_str}" );
      throw error => $e_str, level => 3, rv => $rv;
   }

   return { core => $core, rv => $rv, sig => $sig, };
}

sub _run_cmd_ipc_run_args {
   my $self = shift; my $opts = $self->_default_run_options( @_ );

   $opts->{err} ||= NUL; $opts->{out} ||= NUL;

   return $opts;
}

sub _run_cmd_system_args {
   my $self = shift; my $opts = $self->_default_run_options( @_ );

   if ($opts->{in} ne 'stdin') {
      $opts->{in_ref} ||= $self->tempfile( $opts->{tempdir} );
      $opts->{in_ref}->print( $opts->{in} );
      $opts->{in} = $opts->{in_ref}->pathname;
   }

   # Different semi-random file names in the temp directory
   $opts->{err_ref} ||= $self->tempfile( $opts->{tempdir} );
   $opts->{out_ref} ||= $self->tempfile( $opts->{tempdir} );
   $opts->{err    } ||= 'out' if ($opts->{async});
   $opts->{err    } ||= $opts->{err_ref}->pathname;
   $opts->{out    } ||= $opts->{out_ref}->pathname;
   return $opts;
}

sub _run_cmd_using_ipc_run {
   my ($self, $cmd, @opts) = @_; my ($buf_err, $buf_out, $error, $h, $rv);

   $cmd->[ 0 ] or throw 'Run command not specified';

   my $opts     = $self->_run_cmd_ipc_run_args( @opts );
   my $cmd_ref  = __partition_command( $cmd );
   my $cmd_str  = join SPC, @{ $cmd }; $opts->{async} and $cmd_str .= ' &';
   my $prog     = basename( $cmd->[ 0 ] );
   my $null     = File::Spec->devnull;
   my $err      = $opts->{err};
   my $out      = $opts->{out};
   my $in       = $opts->{in };
   my @cmd_args = ();

   if    ($in  eq 'null')   { push @cmd_args, "0<${null}"     }
   elsif (blessed $in)      { push @cmd_args, "0<${in}"       }
   elsif ($in  ne 'stdin')  { push @cmd_args, '0<', \$in      }

   if    ($out eq 'null')   { push @cmd_args, "1>${null}"     }
   elsif (blessed $out)     { push @cmd_args, "1>${out}"      }
   elsif ($out ne 'stdout') { push @cmd_args, '1>', \$buf_out }

   if    ($err eq 'out')    { push @cmd_args, '2>&1'          }
   elsif ($err eq 'null')   { push @cmd_args, "2>${null}"     }
   elsif (blessed $err)     { push @cmd_args, "2>${err}"      }
   elsif ($err ne 'stderr') { push @cmd_args, '2>', \$buf_err }

   $opts->{debug} and $self->log->debug( "Running ${cmd_str}" );

   try   { ($rv, $h) = __ipc_run_harness( $opts, $cmd_ref, @cmd_args ) }
   catch { throw $_ };

   $opts->{debug} and $self->log->debug( "Run harness returned ${rv}" );

   my $sig = $rv & 127; my $core = $rv & 128; $rv = $rv >> 8;

   if ($opts->{async}) {
      my $pid = $opts->{pid_ref}->chomp->getline || -1; $opts->{pid_ref}->close;

      $out = "Started ${prog}(${pid}) in the background";

      return $self->response_class->new( core => $core, harness => $h,
                                         out  => $out,  pid     => $pid,
                                         rv   => $rv,   sig     => $sig );
   }

   my ($stderr, $stdout);

   if ($out ne 'null' and $out ne 'stdout') {
       not blessed $out and $out = __run_cmd_filter_out( $stdout = $buf_out );
   }
   else { $out = $stdout = NUL }

   if    ($err eq 'out') { $stderr = $stdout; $error = $out; chomp $error }
   elsif (blessed $err)  { $stderr = $error = $err->all; chomp $error }
   elsif ($err ne 'null' and $err ne 'stderr') {
      $stderr = $error = $buf_err; chomp $error;
   }
   else { $stderr = $error = NUL }

   if ($rv > $opts->{expected_rv}) {
      $error ||= "Unknown error rv ${rv}";
      $opts->{debug} and $self->log->debug( "RV ${rv}: ${error}" );
      throw error => $error, out => $out, rv => $rv;
   }

   return $self->response_class->new( core   => $core,   out    => $out,
                                      rv     => $rv,     sig    => $sig,
                                      stderr => $stderr, stdout => $stdout );
}

sub _run_cmd_using_system {
   my ($self, $cmd, @opts) = @_; my ($error, $msg, $rv);

   my $opts = $self->_run_cmd_system_args( @opts );
   my $prog = basename( (split SPC, $cmd)[ 0 ] );
   my $null = File::Spec->devnull;
   my $err  = $opts->{err};
   my $out  = $opts->{out};
   my $in   = $opts->{in };

   $cmd .= $in  eq 'stdin'  ? NUL : $in  eq 'null' ? " 0<${null}" : " 0<${in}";
   $cmd .= $out eq 'stdout' ? NUL : $out eq 'null' ? " 1>${null}" : " 1>${out}";
   $cmd .= $err eq 'stderr' ? NUL : $err eq 'null' ? " 2>${null}"
                                  : $err ne 'out'  ? " 2>${err}"  : ' 2>&1';

   $cmd .= ' & echo $! 1>'.$opts->{pid_ref}->pathname if ($opts->{async});

   $opts->{debug} and $self->log->debug( "Running ${cmd}" );

   {  local ($CHILD_ERROR, $EVAL_ERROR, $OS_ERROR);
      local ($CHILD_ENUM, $CHILD_PID) = ( 0, 0 );

      eval { local $SIG{CHLD} = \&__handler; $rv = system $cmd };

      $EVAL_ERROR and throw $EVAL_ERROR; my $os_error = $OS_ERROR;

      $msg = "System rv ${rv} child pid ${CHILD_PID} error ${CHILD_ENUM}";

      $opts->{debug} and $self->log->debug( $msg );
      # On some systems the child handler reaps the child process so the system
      # call returns -1 and sets $OS_ERROR to 'No child processes'. This line
      # and the child handler code fix the problem
      $rv == -1 and $CHILD_PID > 0 and $rv = $CHILD_ENUM;

      if ($rv == -1) {
         $error = 'Program [_1] failed to start: [_2]';
         throw error => $error, args  => [ $prog, $os_error ], rv => -1;
      }
   }

   my $sig = $rv & 127; my $core = $rv & 128; $rv = $rv >> 8;

   my ($stderr, $stdout);

   if ($opts->{async}) {
      if ($rv != 0) {
         $error = 'Program [_1] failed to start';
         throw error => $error, args => [ $prog ], rv => $rv;
      }

      my $pid = $opts->{pid_ref}->chomp->getline || -1; $opts->{pid_ref}->close;

      $out = "Started ${prog}(${pid}) in the background";

      return $self->response_class->new( core => $core, out => $out,
                                         pid  => $pid,  rv  => $rv,
                                         sig  => $sig );
   }

   if ($out ne 'stdout' and $out ne 'null' and -f $out) {
      $out = __run_cmd_filter_out( $stdout = $self->io( $out )->slurp );
   }
   else { $out = $stdout = NUL }

   if ($err eq 'out') { $stderr = $stdout; $error = $out; chomp $error }
   elsif ($err ne 'stderr' and $err ne 'null' and -f $err) {
      $stderr = $error = $self->io( $err )->slurp; chomp $error;
   }
   else { $stderr = $error = NUL }

   if ($rv > $opts->{expected_rv}) {
      $error ||= "Unknown error rv ${rv}";
      $opts->{debug} and $self->log->debug( "RV ${rv}: ${error}" );
      throw error => $error, out => $out, rv => $rv;
   }

   return $self->response_class->new( core   => $core,   out    => $out,
                                      rv     => $rv,     sig    => $sig,
                                      stderr => $stderr, stdout => $stdout );
}

sub _set_fields {
   my ($self, $has, $p) = @_; my $flds = {};

   $flds->{id   } = $has->{pid   } ? $p->pid                  : NUL;
   $flds->{pid  } = $has->{pid   } ? $p->pid                  : NUL;
   $flds->{ppid } = $has->{ppid  } ? $p->ppid                 : NUL;
   $flds->{start} = $has->{start } ? time2str( '%d/%m %H:%M', $p->start ) : NUL;
   $flds->{state} = $has->{state } ? $p->state                : NUL;
   $flds->{tty  } = $has->{ttydev} ? $p->ttydev               : NUL;
   $flds->{time } = $has->{time  } ? int $p->time / 1_000_000 : NUL;
   $flds->{uid  } = $has->{uid   } ? getpwuid $p->uid         : NUL;

   if ($has->{ttydev} and $p->ttydev) {
      $flds->{tty} = $p->ttydev;
   }
   elsif ($has->{ttynum} and $p->ttynum) {
      $flds->{tty} = $p->ttynum;
   }
   else { $flds->{tty} = NUL }

   if ($has->{rss} and $p->rss) {
      $flds->{size} = int $p->rss/1_024;
   }
   elsif ($has->{size} and $p->size) {
      $flds->{size} = int $p->size/1_024;
   }
   else { $flds->{size} = NUL }

   if ($has->{exec} and $p->exec) {
      $flds->{cmd} = substr $p->exec, 0, 64;
   }
   elsif ($has->{cmndline} and $p->cmndline) {
      $flds->{cmd} = substr $p->cmndline, 0, 64;
   }
   elsif ($has->{fname} and $p->fname) {
      $flds->{cmd} = substr $p->fname, 0, 64;
   }
   else { $flds->{cmd} = NUL }

   return $flds;
}

# Private functions
sub __cleaner {
   local $OS_ERROR; # So that wait does not step on existing value

   $CHILD_PID = wait; $CHILD_ENUM = (255 << 8) + 13; $SIG{PIPE} = \&__cleaner;

   return;
}

sub __cmd_matches_pattern {
   my ($cmd, $pattern) = @_;

   return !$pattern || $cmd =~ m{ $pattern }msx ? TRUE : FALSE;
}

sub __handler {
   local $OS_ERROR; # So that waitpid does not step on existing value

   while ((my $child_pid = waitpid -1, WNOHANG) > 0) {
      if (WIFEXITED( $CHILD_ERROR ) and $child_pid > ($CHILD_PID || 0)) {
         $CHILD_PID = $child_pid; $CHILD_ENUM = $CHILD_ERROR;
      }
   }

   $SIG{CHLD} = \&__handler; # In case of unreliable signals
   return;
}

sub __ipc_run_harness {
   my ($opts, $cmd_ref, @cmd_args) = @_;

   if ($opts->{async}) {
      is_coderef $cmd_ref->[ 0 ] and $cmd_ref = $cmd_ref->[ 0 ];

      my $h = IPC::Run::harness( $cmd_ref, @cmd_args, init => sub {
         $opts->{pid_ref}->print( $PID )->close }, '&' );

      $h->start; return ( 0, $h );
   }

   my $h  = IPC::Run::harness( $cmd_ref, @cmd_args ); $h->run;
   my $rv = $h->full_result || 0; $rv =~ m{ unknown }msx and throw $rv;

   return ( $rv, $h );
}

sub __new_proc_process_table {
   require Proc::ProcessTable;

   return Proc::ProcessTable->new( cache_ttys => TRUE );
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

sub __proc_belongs_to_user {
   my ($puid, $user) = @_;

   return (!$user || $user eq 'All' || $user eq loginid $puid) ? TRUE : FALSE;
}

sub __pscomp {
   my ($arg1, $arg2) = @_; my $result;

   $result = $arg1->{uid} cmp $arg2->{uid};
   $result = $arg1->{pid} <=> $arg2->{pid} if ($result == 0);

   return $result;
}

sub __run_cmd_filter_out {
   return join "\n", map    { strip_leader $_ }
                     grep   { not m{ (?: Started | Finished ) }msx }
                     split m{ [\n] }msx, $_[ 0 ];
}

1;

__END__

=pod

=head1 Name

Class::Usul::IPC - List/Create/Delete processes

=head1 Version

This documents version v0.30.$Rev: 1 $

=head1 Synopsis

   use Class::Usul::IPC;

   my $ipc = Class::Usul::IPC->new;

   $result_object = $ipc->run_cmd( [ qw( ls -l ) ] );

=head1 Description

Displays the process table and allows signals to be sent to selected
processes

=head1 Subroutines/Methods

=head2 child_list

   @pids = $self->child_list( $pid );

Called with a process id for an argument this method returns a list of child
process ids

=head2 popen

   $response = $self->popen( $cmd, @opts );

Uses L<IPC::Open3> to fork a command and pipe the lines of input into
it. Returns a C<Class::Usul::Response::IPC> object. The response
object's C<out> method returns the B<STDOUT> from the command. Throws
in the event of an error. See L</run_cmd> for a full list of options and
response attributes

=head2 process_exists

   $bool = $self->process_exists( file => $path, pid => $pid );

Tests for the existence of the specified process. Either specify a
path to a file containing the process id or specify the id directly

=head2 process_table

Generates the process table data used by the L<HTML::FormWidget> table
subclass. Called by L<Class::Usul::Model::Process/proc_table>

=head2 run_cmd

   $response = $self->run_cmd( $cmd, $opts );

Runs the given command. If C<$cmd> is a string then an implementation
based on the C<system> function is used. If C<$cmd> is an arrayref
then an implementation based on L<IPC::Run> is used if it is
installed. If L<IPC::Run> is not installed then the arrayref is joined
with spaces and the C<system> implementation is used. The keys of the
C<$opts> hashref are:

=over 3

=item async

If C<async> is true then the command is run in the background

=item debug

Debug status. Defaults to C<< $self->debug >>

=item err

Passing I<< err => q(out) >> mixes the normal and error output
together

=item in

Input to the command. Can be a string or an array ref

=item out

Destination for standard output

=item tempdir

Directory used to store the lock file and lock table if the C<fcntl> backend
is used. Defaults to C<< $self->tempdir >>

=back

Returns a L<Class::Usul::Response::IPC> object or throws an
error. The response object has the following methods:

=over 3

=item C<core>

Returns true if the command generated a core dump

=item C<err>

Contains a cleaned up version of the commands C<STDERR>

=item C<out>

Contains a cleaned up version of the commands C<STDOUT>

=item C<pid>

The id of the background process. Only set if command is running I<async>

=item C<rv>

The return value of the command

=item C<sig>

If the command died as the result of receiving a signal return the
signal number

=item C<stderr>

Contains the commands C<STDERR>

=item C<stdout>

Contains the commands C<STDOUT>

=back

On C<MSWin32> the L</popen> method is used instead. That method does not
support the C<async> option

=head2 signal_process

Send a signal the the selected processes. Invokes the C<suid> root wrapper

=head2 signal_process_as_root

   $self->signal_process( [{] param => value, ... [}] );

This is called by processes running as root to send signals to
selected processes. The passed parameters can be either a list of key
value pairs or a hash ref. Either a single C<pid>, or an array ref
C<pids>, or C<file> must be passwd. The C<file> parameter should be a
path to a file containing process ids one per line. The C<sig> defaults to
C<TERM>. If the C<flag> parameter is set to C<one> then the given signal
will be sent once to each selected process. Otherwise each process and
all of it's children will be sent the signal. If the C<force>
parameter is set to true the after a grace period each process and
it's children are sent signal C<KILL>

=head2 __cleaner

This interrupt handler traps the pipe signal

=head2 __handler

This interrupt handler traps the child signal

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Class::Usul::Constants>

=item L<Class::Usul::Response::IPC>

=item L<Class::Usul::Response::Table>

=item L<IPC::Open3>

=item L<IPC::SysV>

=item L<Module::Load::Conditional>

=item L<POSIX>

=item L<Proc::ProcessTable>

=item L<Try::Tiny>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
