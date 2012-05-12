# @(#)$Id$

package Class::Usul::IPC;

use strict;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Null;
use Class::Usul::File;
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Constraints  qw(ConfigType LogType);
use Class::Usul::Functions    qw(arg_list is_arrayref merge_attributes
                                 strip_leader throw);
use Class::Usul::Response::IPC;
use Class::Usul::Response::Table;
use Class::Usul::Time         qw(time2str);
use English                   qw(-no_match_vars);
use File::Basename            qw(basename);
use File::Spec;
use IO::Handle;
use IO::Select;
use IPC::Open3;
use Module::Load::Conditional qw(can_load);
use POSIX                     qw(WIFEXITED WNOHANG);
use Proc::ProcessTable;
use Try::Tiny;

our ($ERROR, $WAITEDPID);

my $SPECIAL_CHARS = do { my $x = join NUL, qw(< > | &); qr{ ([$x]) }mx };

has 'config' => is => 'ro', isa => ConfigType, required => TRUE;

has 'debug'  => is => 'rw', isa => Bool,       default  => FALSE;

has 'log'    => is => 'ro', isa => LogType,
   default   => sub { Class::Null->new };

has '_file'  => is => 'ro', isa => Object, builder => '_build__file',
   handles   => [ qw(io) ], init_arg => undef, lazy => TRUE, reader => 'file';

around BUILDARGS => sub {
   my ($next, $self, @args) = @_; my $attr = $self->$next( @args );

   my $builder = delete $attr->{builder}; $builder or return $attr;

   merge_attributes $attr, $builder, {}, [ qw(config debug file log) ];

   return $attr;
};

sub child_list {
   my ($self, $pid, $procs) = @_; my ($child, $p, $t); my @pids = ();

   unless (defined $procs) {
      $t     = Proc::ProcessTable->new;
      $procs = { map { $_->pid => $_->ppid } @{ $t->table } };
   }

   if (exists $procs->{ $pid }) {
      for $child (grep { $procs->{ $_ } == $pid } keys %{ $procs }) {
         push @pids, $self->child_list( $child, $procs ); # Recurse
      }

      push @pids, $pid;
   }

   return @pids;
}

sub popen {
   my ($self, $cmd, @rest) = @_; my ($e, $pid, @ready);

   $cmd or throw 'Command not specified';

   is_arrayref $cmd and $cmd = join SPC, @{ $cmd };

   my $args = arg_list @rest;
   my $err  = IO::Handle->new();
   my $out  = IO::Handle->new();
   my $in   = IO::Handle->new();
   my $res  = Class::Usul::Response::IPC->new();

   {  local ($CHILD_ERROR, $ERRNO, $WAITEDPID); local $ERROR = FALSE;

      try {
         local $SIG{CHLD} = \&__handler; local $SIG{PIPE} = \&__cleaner;

         $pid = open3( $in, $out, $err, $cmd );

         for my $line (@{ $args->{in} || [] }) {
            print {$in} $line
               or throw error => 'IO error [_1]', args =>[ $ERRNO ];
         }

         $in->close;
      }
      catch { $e = $_ };

      not $e and $e = $ERROR and $e .= " - whilst executing ${cmd}";
   }

   if ($e) { $err->close; $out->close; throw $e }

   my $selector = IO::Select->new(); $selector->add( $err, $out );

   while (@ready = $selector->can_read) {
      for my $fh (@ready) {
         if (fileno $fh == fileno $err) { $e = __read_all_from( $fh ) }
         else { $res->out( $res->stdout( __read_all_from( $fh ) ) ) }

         if ($fh->eof) { $selector->remove( $fh ); $fh->close }
      }
   }

   waitpid $pid, 0; $e and throw $e;

   return $res;
}

sub process_exists {
   my ($self, @rest) = @_; my ($io, $file);

   my $args = arg_list @rest; my $pid = $args->{pid};

   $file = $args->{file} and $io = $self->io( $file ) and $io->is_file
      and $pid = $io->chomp->lock->getline;

   (not $pid or $pid !~ m{ \d+ }mx) and return FALSE;

   return CORE::kill 0, $pid ? TRUE : FALSE;
}

sub process_table {
   my ($self, @rest) = @_;

   my $args  = arg_list @rest;
   my $pat   = $args->{pattern};
   my $ptype = $args->{type   };
   my $user  = $args->{user   };
   my $ppt   = Proc::ProcessTable->new( cache_ttys => TRUE );
   my $has   = { map { $_ => TRUE } $ppt->fields };
   my $table = __new_process_table();
   my $count = 0;

   $table->values( [] );

   if ($ptype == 3) {
      my %procs = map { $_->pid => $_ } @{ $ppt->table };
      my @pids  = $self->_list_pids_by_file_system( $args->{fsystem} );

      for my $p (grep { defined } map { $procs{ $_ } } @pids) {
         push @{ $table->values }, $self->_set_fields( $has, $p );
         $count++;
      }
   }
   else {
      for my $p (@{ $ppt->table }) {
         if (   ($ptype == 1 and __proc_belongs_to_user( $p->uid, $user ))
             or ($ptype == 2 and __cmd_matches_pattern( $p->cmndline, $pat ))){
            push @{ $table->values }, $self->_set_fields( $has, $p );
            $count++;
         }
      }
   }

   @{ $table->values } = sort { __pscomp( $a, $b ) } @{ $table->values };
   $table->count( $count );
   return $table;
}

sub run_cmd {
   my ($self, $cmd, @rest) = @_; $cmd or throw 'Run command not specified';

   if (is_arrayref $cmd) {
      if (can_load( modules => { 'IPC::Run' => q(0.84) } )) {
         return $self->_run_cmd_using_ipc_run( $cmd, @rest );
      }

      $cmd = join SPC, @{ $cmd };
   }

   return $self->_run_cmd_using_system( $cmd, @rest );
}

sub signal_process {
   my ($self, $flag, $sig, $pids) = @_; my $opts = [];

   $sig  and push @{ $opts }, q(-o), "sig=$sig";
   $flag and push @{ $opts }, q(-o), q(flag=one);

   my $cmd = [ $self->config->suid, qw(-n -c signal_process),
               @{ $opts }, q(--), @{ $pids || [] } ];

   return $self->run_cmd( $cmd );
}

sub signal_process_as_root {
   my ($self, @rest) = @_; my ($file, $io);

   my $args = arg_list @rest;
   my $sig  = $args->{sig } || q(TERM);
   my $pids = $args->{pids} || [];

   $args->{pid} and push @{ $pids }, $args->{pid};

   if ($file = $args->{file}
       and $io = $self->io( $file ) and $io->is_file) {
      push @{ $pids }, $io->chomp->lock->getlines;
      $sig eq q(TERM) and unlink $file;
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

      CORE::kill q(KILL), $_ for (@pids);
   }

   return OK;
}

# Private methods

sub _build__file {
   return Class::Usul::File->new( tempdir => $_[ 0 ]->config->tempdir );
}

sub _list_pids_by_file_system {
   my ($self, $fsystem) = @_; $fsystem or return ();

   my $args = { err => q(null), expected_rv => 1 };
   # TODO: Make fuser OS dependent
   my $data = $self->run_cmd( "fuser ${fsystem}", $args )->out || NUL;

   $data =~ s{ [^0-9\s] }{}gmx; $data =~ s{ \s+ }{ }gmx;

   return sort { $a <=> $b } grep { defined && length } split SPC, $data;
}

sub _run_cmd_ipc_run_args {
   my ($self, @rest) = @_; my $args = arg_list @rest;

   $args->{debug      } ||= $self->debug;
   $args->{expected_rv} ||= 0;
   $args->{err        } ||= NUL;
   $args->{out        } ||= NUL;
   $args->{in         } ||= q(stdin);

   is_arrayref $args->{in} and $args->{in} = join "\n", @{ $args->{in} };

   return $args;
}

sub _run_cmd_system_args {
   my ($self, @rest) = @_; my $args = arg_list @rest;

   $args->{debug      } ||= $self->debug;
   $args->{expected_rv} ||= 0;
   $args->{tempdir    } ||= $self->file->tempdir;
   # Three different semi-random file names in the temp directory
   $args->{err_ref    } ||= $self->file->tempfile( $args->{tempdir} );
   $args->{out_ref    } ||= $self->file->tempfile( $args->{tempdir} );
   $args->{pid_ref    } ||= $self->file->tempfile( $args->{tempdir} );
   $args->{err        } ||= q(out) if ($args->{async});
   $args->{err        } ||= $args->{err_ref}->pathname;
   $args->{out        } ||= $args->{out_ref}->pathname;
   $args->{in         } ||= q(stdin);

   return $args;
}

sub _run_cmd_using_ipc_run {
   my ($self, $cmd, @rest) = @_; my ($buf_err, $buf_out, $error, $msg, $rv);

   my $args     = $self->_run_cmd_ipc_run_args( @rest );
   my $cmd_ref  = __partition_command( $cmd );
   my $cmd_str  = join SPC, @{ $cmd };
   my $null     = File::Spec->devnull;
   my $err      = $args->{err};
   my $out      = $args->{out};
   my $in       = $args->{in };
   my @cmd_args = ();

   if    ($in  eq q(null))   { push @cmd_args, q(0<).$null      }
   elsif ($in  ne q(stdin))  { push @cmd_args, q(0<), \$in      }

   if    ($out eq q(null))   { push @cmd_args, q(1>).$null      }
   elsif ($out ne q(stdout)) { push @cmd_args, q(1>), \$buf_out }

   if    ($err eq q(out))    { push @cmd_args, q(2>&1)          }
   elsif ($err eq q(null))   { push @cmd_args, q(2>).$null      }
   elsif ($err ne q(stderr)) { push @cmd_args, q(2>), \$buf_err }

   $args->{debug} and $self->log->debug( "Running ${cmd_str}" );

   try   { $rv = __ipc_run_harness( $cmd_ref, @cmd_args ) }
   catch { throw $_ };

   $args->{debug} and $self->log->debug( "Run harness returned ${rv}\n" );

   my $res = Class::Usul::Response::IPC->new();

   $res->sig( $rv & 127 ); $res->core( $rv & 128 ); $rv = $res->rv( $rv >> 8 );

   if ($out ne q(null) and $out ne q(stdout)) {
      $res->out( __run_cmd_filter_out( $res->stdout( $buf_out ) ) );
   }

   if ($err eq q(out)) {
      $res->stderr( $res->stdout ); $error = $res->out; chomp $error;
   }
   elsif ($err ne q(null) and $err ne q(stderr)) {
      $res->stderr( $error = $buf_err ); chomp $error;
   }
   else { $error = NUL }

   if ($rv > $args->{expected_rv}) {
      $error ||= 'Unknown error'; $msg = "Return value ${rv} error ${error}";
      $args->{debug} and $self->log->debug( $msg );
      throw error => $error, rv => $rv;
   }

   return $res;
}

sub _run_cmd_using_system {
   my ($self, $cmd, @rest) = @_; my ($error, $msg, $rv);

   my $args = $self->_run_cmd_system_args( @rest );
   my $prog = basename( (split SPC, $cmd)[ 0 ] );
   my $null = File::Spec->devnull;
   my $err  = $args->{err};
   my $out  = $args->{out};
   my $in   = $args->{in };

   $cmd .= $in  eq q(stdin)  ? NUL : $in  eq q(null) ? ' 0<'.$null
                                                     : ' 0<'.$in;
   $cmd .= $out eq q(stdout) ? NUL : $out eq q(null) ? ' 1>'.$null
                                                     : ' 1>'.$out;
   $cmd .= $err eq q(stderr) ? NUL : $err eq q(null) ? ' 2>'.$null
                                   : $err ne q(out)  ? ' 2>'.$err
                                                     : ' 2>&1';

   $cmd .= ' & echo $! 1>'.$args->{pid_ref}->pathname if ($args->{async});

   $args->{debug} and $self->log->debug( "Running ${cmd}" );

   {  local ($CHILD_ERROR, $ERRNO, $EVAL_ERROR);
      local $WAITEDPID = 0; local $ERROR = OK;

      eval { local $SIG{CHLD} = \&__handler; $rv = system $cmd };

      $EVAL_ERROR and throw $EVAL_ERROR;

      $msg = "System returned ${rv} waitedpid ${WAITEDPID} error ${ERROR}\n";

      $args->{debug} and $self->log->debug( $msg );
#     On some systems the child handler reaps the child process so the system
#     call returns -1 and sets $ERRNO to No child processes. This line and
#     the child handler code fix the problem
      $rv == -1 and $WAITEDPID > 0 and $rv = $ERROR;

      if ($rv == -1) {
         $error = 'Program [_1] failed to start: [_2]';
         throw error => $error, args  => [ $prog, $ERRNO ], rv => -1;
      }
   }

   my $res = Class::Usul::Response::IPC->new();

   $res->sig( $rv & 127 ); $res->core( $rv & 128 ); $rv = $res->rv( $rv >> 8 );

   if ($args->{async}) {
      if ($rv != 0) {
         $error = 'Program [_1] failed to start';
         throw error => $error, args => [ $prog ], rv => $rv;
      }

      my $pid = $args->{pid_ref}->chomp->getline || 'unknown pid';

      $res->out( "Started ${prog}(${pid}) in the background" );
      $res->pid( $pid );
      return $res;
   }

   if ($out ne q(stdout) and $out ne q(null) and -f $out) {
      my $text = $self->io( $out )->slurp;

      $res->out( __run_cmd_filter_out( $res->stdout( $text ) ) );
   }

   if ($err eq q(out)) {
      $res->stderr( $res->stdout ); $error = $res->out; chomp $error;
   }
   elsif ($err ne q(stderr) and $err ne q(null) and -f $err) {
      $res->stderr( $error = $self->io( $err )->slurp ); chomp $error;
   }
   else { $error = NUL }

   if ($rv > $args->{expected_rv}) {
      $error ||= 'Unknown error'; $msg = "Return value ${rv} error ${error}";
      $args->{debug} and $self->log->debug( $msg );
      throw error => $error, rv => $rv;
   }

   return $res;
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

# Private subroutines

sub __cleaner {
   $ERROR = q(SIGPIPE); $WAITEDPID = wait; $SIG{PIPE} = \&__cleaner; return;
}

sub __cmd_matches_pattern {
   my ($cmd, $pattern) = @_;

   return !$pattern || $cmd =~ m{ $pattern }msx ? TRUE : FALSE;
}

sub __handler {
   local $ERRNO; # so that waitpid does not step on existing value

   while ((my $child_pid = waitpid -1, WNOHANG) > 0) {
      if (WIFEXITED( $CHILD_ERROR ) and $child_pid > $WAITEDPID) {
         $WAITEDPID = $child_pid; $ERROR = $CHILD_ERROR;
      }
   }

   $SIG{CHLD} = \&__handler; # in case of unreliable signals
   return;
}

sub __ipc_run_harness {
   my $h = IPC::Run::harness( @_ ); $h->run; return $h->full_result;
}

sub __new_process_table {
   my $table = Class::Usul::Response::Table->new
      ( align    => { uid   => 'left',   pid   => 'right',
                      ppid  => 'right',  start => 'right',
                      tty   => 'right',  time  => 'right',
                      size  => 'right',  state => 'left',
                      cmd   => 'left' },
        flds     => [ qw(uid pid ppid start time size state tty cmd) ],
        labels   => { uid   => 'User',   pid   => 'PID',
                      ppid  => 'PPID',   start => 'Start Time',
                      tty   => 'TTY',    time  => 'Time',
                      size  => 'Size',   state => 'State',
                      cmd   => 'Command' },
        typelist => { pid   => q(numeric), ppid => q(numeric),
                      start => q(date),    size => q(numeric),
                      time  => q(numeric) },
        wrap     => { cmd => 1 }, );

   return $table;
}

sub __partition_command {
   my $cmd = shift; my $aref = []; my @command = ();

   for my $item (grep { defined && length } @{ $cmd }) {
      if ($item =~ $SPECIAL_CHARS) { push @command, $aref, $item; $aref = [] }
      else { push @{ $aref }, $item }
   }

   if ($aref->[ 0 ]) {
      if ($command[ 0 ]) { push @command, $aref }
      else { @command = @{ $aref } }
   }

   return \@command;
}

sub __proc_belongs_to_user {
   my ($puid, $user) = @_;

   return !$user || $user eq q(All) || $user eq getpwuid $puid ? TRUE : FALSE;
}

sub __pscomp {
   my ($arg1, $arg2) = @_; my $result;

   $result = $arg1->{uid} cmp $arg2->{uid};
   $result = $arg1->{pid} <=> $arg2->{pid} if ($result == 0);

   return $result;
}

sub __read_all_from {
   my $fh = shift; local $RS = undef; return <$fh>;
}

sub __run_cmd_filter_out {
   return join "\n", map    { strip_leader $_ }
                     grep   { not m{ (?: Started | Finished ) }msx }
                     split m{ [\n] }msx, $_[ 0 ];
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

Class::Usul::IPC - List/Create/Delete processes

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use parent qw(Class::Usul::IPC);

=head1 Description

Displays the process table and allows signals to be sent to selected
processes

=head1 Subroutines/Methods

=head2 child_list

   @pids = $self->child_list( $pid );

Called with a process id for an argument this method returns a list of child
process ids

=head2 popen

   $response = $self->popen( $cmd, @input );

Uses L<IPC::Open3> to fork a command and pipe the lines of input into
it. Returns a C<Class::Usul::Response::IPC> object. The response
object's C<out> method returns the B<STDOUT> from the command. Throws
in the event of an error

=head2 process_exists

   $bool = $self->process_exists( file => $path, pid => $pid );

Tests for the existence of the specified process. Either specify a
path to a file containing the process id or specify the id directly

=head2 process_table

Generates the process table data used by the L<HTML::FormWidget> table
subclass. Called by L<Class::Usul::Model::Process/proc_table>

=head2 run_cmd

   $response = $self->run_cmd( $cmd, $args );

Runs the given command by calling C<system>. The keys of the C<$args> hash are:

=over 3

=item async

If I<async> is true then the command is run in the background

=item debug

Debug status. Defaults to C<< $self->debug >>

=item err

Passing I<< err => q(out) >> mixes the normal and error output
together

=item in

Input to the command

=item log

Logging object

=item out

Destination for standard output

=item tempdir

Directory used to store the lock file and lock table if the C<fcntl> backend
is used. Defaults to C<< $self->tempdir >>

=back

Returns a L<Class::Usul::Response::IPC> object or throws an
error. The response object has the following methods:

=over 3

=item B<core>

Returns true if the command generated a core dump

=item B<err>

Contains a cleaned up version of the command's B<STDERR>

=item B<out>

Contains a cleaned up version of the command's B<STDOUT>

=item B<pid>

The id of the background process. Only set if command is running I<async>

=item B<rv>

The return value of the command

=item B<sig>

If the command died as the result of receiving a signal return the
signal number

=item B<stderr>

Contains the command's B<STDERR>

=item B<stdout>

Contains the command's B<STDOUT>

=back

=head2 signal_process

Send a signal the the selected processes. Invokes the I<suid> root wrapper

=head2 signal_process_as_root

   $self->signal_process( [{] param => value, ... [}] );

This is called by processes running as root to send signals to
selected processes. The passed parameters can be either a list of key
value pairs or a hash ref. Either a single B<pid>, or an array ref
B<pids>, or B<file> must be passwd. The B<file> parameter should be a
path to a file containing pids one per line. The B<sig> defaults to
I<TERM>. If the B<flag> parameter is set to I<one> then the given signal
will be sent once to each selected process. Otherwise each process and
all of it's children will be sent the signal. If the B<force>
parameter is set to true the after a grace period each process and
it's children are sent signal I<KILL>

=head2 __cleaner

This interrupt handler traps the pipe signal

=head2 __handler

This interrupt handler traps the child signal

=head1 Diagnostics

None

=head1 Configuration and Environment

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

Copyright (c) 2009 Peter Flanigan. All rights reserved

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
