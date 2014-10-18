package Class::Usul::IPC;

use 5.01;
use namespace::autoclean;

use Moo;
use Class::Null;
use Class::Usul::Constants    qw( EXCEPTION_CLASS FALSE NUL OK SPC TRUE );
use Class::Usul::Functions    qw( arg_list get_user io loginid throw );
use Class::Usul::IPC::Cmd;
use Class::Usul::Time         qw( time2str );
use Class::Usul::Types        qw( BaseType Bool LoadableClass );
use English                   qw( -no_match_vars );
use Module::Load::Conditional qw( can_load );
use Unexpected::Functions     qw( Unspecified );

# Public attributes
has 'cache_ttys'  => is => 'ro',   isa => Bool, default => TRUE;

has 'table_class' => is => 'lazy', isa => LoadableClass,
   default        => 'Class::Usul::Response::Table',
   coerce         => LoadableClass->coercion;

# Private attributes
has '_usul'       => is => 'ro', isa => BaseType,
   handles        => [ 'config', 'log' ], init_arg => 'builder',
   required       => TRUE, weak_ref => TRUE;

# Public methods
sub child_list {
   my ($self, $pid, $procs) = @_; my ($child, $ppt); my @pids = ();

   unless (defined $procs) {
      $ppt   = $self->_new_proc_process_table;
      $procs = { map { $_->pid => $_->ppid } @{ $ppt->table } };
   }

   if (exists $procs->{ $pid }) {
      for $child (grep { $procs->{ $_ } == $pid } keys %{ $procs }) {
         push @pids, $self->child_list( $child, $procs ); # Recurse
      }

      push @pids, $pid;
   }

   return sort { $a <=> $b } @pids;
}

sub popen {
   return shift->run_cmd( @_ );
}

sub process_exists {
   my ($self, @args) = @_; my $args = arg_list @args;

   my $pid = $args->{pid}; my ($io, $file);

   $file = $args->{file} and $io = io( $file ) and $io->is_file
      and $pid = $io->chomp->lock->getline;

   (not $pid or $pid !~ m{ \d+ }mx) and return FALSE;

   return (CORE::kill 0, $pid) ? TRUE : FALSE;
}

sub process_table {
   my ($self, @args) = @_; my $args = arg_list @args;

   my $pat   = $args->{pattern};
   my $ptype = $args->{type   } // 1;
   my $user  = $args->{user   } // get_user->name;
   my $ppt   = $self->_new_proc_process_table;
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
   my ($self, $cmd, @args) = @_; my $attr = arg_list @args;

   $attr->{cmd    } = $cmd or throw Unspecified, args => [ 'command' ];
   $attr->{log    } = $self->log;
   $attr->{rundir } = $self->config->rundir;
   $attr->{tempdir} = $self->config->tempdir;

   return Class::Usul::IPC::Cmd->new( $attr )->run_cmd;
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

   if ($file = $args->{file} and $io = io( $file ) and $io->is_file) {
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
sub _list_pids_by_file_system {
   my ($self, $fsystem) = @_; $fsystem or return ();

   my $opts = { err => 'null', expected_rv => 1 };
   # TODO: Make fuser OS dependent
   my $data = $self->run_cmd( "fuser ${fsystem}", $opts )->out || NUL;

   $data =~ s{ [^0-9\s] }{}gmx; $data =~ s{ \s+ }{ }gmx;

   return sort { $a <=> $b } grep { defined && length } split SPC, $data;
}

sub _new_proc_process_table {
   my $self = shift;

   can_load( modules => { 'Proc::ProcessTable' => '0' } )
      and return Proc::ProcessTable->new( cache_ttys => $self->cache_ttys );

   return Class::Null->new;
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
sub __cmd_matches_pattern {
   my ($cmd, $pattern) = @_;

   return !$pattern || $cmd =~ m{ $pattern }msx ? TRUE : FALSE;
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

1;

__END__

=pod

=head1 Name

Class::Usul::IPC - List/Create/Delete processes

=head1 Synopsis

   use Class::Usul;
   use Class::Usul::IPC;

   my $ipc = Class::Usul::IPC->new( builder => Class::Usul->new );

   $result_object = $ipc->run_cmd( [ qw( ls -l ) ] );

=head1 Description

Displays the process table and allows signals to be sent to selected
processes

=head1 Configuration and Environment

Defines these attributes;

=over 3

=item C<cache_ttys>

Boolean that defaults to true. Passed to L<Proc::ProcessTable>

=back

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

Runs the given command. If C<$cmd> is a string then an implementation based on
the L<IPC::Open3> function is used. If C<$cmd> is an array reference then an
implementation using C<fork> and C<exec> in L<Class::Usul::IPC::Cmd> is used to
execute the command. If the command contains pipes then an implementation based
on L<IPC::Run> is used if it is installed. If L<IPC::Run> is not installed then
the arrayref is joined with spaces and the C<system> implementation is
used. The C<$opts> hash reference and the C<$response> object are described
in L<Class::Usul::IPC::Cmd>

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

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Class::Usul::Constants>

=item L<Class::Usul::IPC::Cmd>

=item L<Class::Usul::Response::IPC>

=item L<Class::Usul::Response::Table>

=item L<Module::Load::Conditional>

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
