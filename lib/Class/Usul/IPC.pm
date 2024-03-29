package Class::Usul::IPC;

use Class::Usul::Constants    qw( EXCEPTION_CLASS FALSE NUL OK SPC TRUE );
use Class::Usul::Functions    qw( arg_list get_user loginid throw );
use Class::Usul::Time         qw( time2str );
use Class::Usul::Types        qw( Bool );
use File::DataClass::IO       qw( io );
use File::DataClass::Types    qw( Path );
use Module::Load::Conditional qw( can_load );
use Class::Null;
use Moo;

=pod

=encoding utf-8

=head1 Name

Class::Usul::IPC - List / create / delete processes

=head1 Synopsis

   use Class::Usul::IPC;

   my $object = Class::Usul::IPC->new();

=head1 Description

Displays the process table and allows signals to be sent to selected
processes

=head1 Configuration and Environment

Defines the following public attributes;

=over 3

=cut

has '_builder' =>
   is       => 'ro',
   handles  => [qw(run_cmd)],
   init_arg => 'builder',
   required => TRUE,
   weak_ref => TRUE;

=item C<cache_ttys>

Boolean that defaults to true. Passed to L<Proc::ProcessTable>

=cut

has 'cache_ttys' => is => 'ro', isa => Bool, default => TRUE;

=item C<suid>

Path to the setuid root wrapper program

=item C<has_suid>

Predicate

=cut

has 'suid' => is => 'ro', isa => Path, predicate => 'has_suid';

=back

=head1 Subroutines/Methods

Defines the following public methods;

=over 3

=item C<BUILDARGS>

=cut

around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_;

   my $attr = $orig->($self, @args);
   my $builder = $attr->{builder};

   $attr->{suid} = $builder->config->suid
      if $builder && $builder->can('config') && $builder->config->can('suid');

   return $attr;
};

=item C<child_list>

   @pids = $self->child_list( $pid );

Called with a process id for an argument this method returns a list of child
process ids

=cut

sub child_list {
   my ($self, $pid, $procs) = @_;

   my ($child, $ppt);
   my @pids = ();

   unless (defined $procs) {
      $ppt   = _new_proc_process_table($self->cache_ttys);
      $procs = { map { $_->pid => $_->ppid } @{$ppt->table} };
   }

   if (exists $procs->{$pid}) {
      for $child (grep { $procs->{$_} == $pid } keys %{$procs}) {
         push @pids, $self->child_list($child, $procs); # Recurse
      }

      push @pids, $pid;
   }

   return sort { $a <=> $b } @pids;
}

=item C<list_pids_by_file_system>

   @pids = $self->list_pids_by_file_system( $file_system );

Returns the list of process ids produced by the C<fuser> command

=cut

sub list_pids_by_file_system {
   my ($self, $fsystem) = @_;

   return () unless $fsystem;

   my $opts = { err => 'null', expected_rv => 1 };
   # TODO: Make fuser OS dependent
   my $data = $self->run_cmd("fuser ${fsystem}", $opts)->out || NUL;

   $data =~ s{ [^0-9\s] }{}gmx; $data =~ s{ \s+ }{ }gmx;

   return sort { $a <=> $b } grep { defined && length } split SPC, $data;
}

=item C<popen>

   $response = $self->popen( $cmd, @opts );

Uses L<IPC::Open3> to fork a command and pipe the lines of input into
it. Returns a L<Class::Usul::Cmd::IPC::Response> object. The response
object's C<out> method returns the B<STDOUT> from the command. Throws
in the event of an error. See L</run_cmd> for a full list of options and
response attributes

=cut

sub popen {
   return shift->run_cmd(@_);
}

=item C<process_exists>

   $bool = $self->process_exists( file => $path, pid => $pid );

Tests for the existence of the specified process. Either specify a
path to a file containing the process id or specify the id directly

=cut

sub process_exists {
   my ($self, @args) = @_;

   my $args = arg_list @args;
   my $pid  = $args->{pid};

   if (my $file = $args->{file}) {
      if (my $io = io $file) {
         $pid = $io->chomp->lock->getline if $io->is_file;
      }
   }

   return FALSE if !$pid || $pid !~ m{ \d+ }mx;

   return (CORE::kill 0, $pid) ? TRUE : FALSE;
}

=item C<process_table>

   $res = $self->process_table( type => ..., );

Returns a hash reference representing the current process table

=cut

sub process_table {
   my ($self, @args) = @_;

   my $args  = arg_list @args;
   my $pat   = $args->{pattern};
   my $ptype = $args->{type} // 1;
   my $user  = $args->{user} // get_user->name;
   my $ppt   = _new_proc_process_table($self->cache_ttys);
   my $has   = { map { $_ => TRUE } $ppt->fields };
   my @rows  = ();
   my $count = 0;

   if ($ptype == 3) {
      my %procs = map { $_->pid => $_ } @{$ppt->table};
      my @pids  = $self->list_pids_by_file_system($args->{fsystem});

      for my $p (grep { defined } map { $procs{$_} } @pids) {
         push @rows, _set_fields($has, $p);
         $count++;
      }
   }
   else {
      for my $p (@{$ppt->table}) {
         if (   ($ptype == 1 and _proc_belongs_to_user($p->uid, $user))
             or ($ptype == 2 and _cmd_matches($p->cmndline, $pat))) {
            push @rows, _set_fields($has, $p);
            $count++;
         }
      }
   }

   return $self->_new_process_table([ sort { _pscomp($a, $b) } @rows ], $count);
}

=item C<signal_process>

Send a signal the the selected processes. Invokes the L</suid> root wrapper

=cut

sub signal_process {
   my ($self, @args) = @_;

   return $self->run_cmd(_signal_cmd($self->suid, @args))
      if $self->has_suid && !is_hashref $args[0];

   my $args = $args[0];
   my $sig  = $args->{sig} // 'TERM';
   my $pids = $args->{pids} // [];

   push @{$pids}, $args->{pid} if $args->{pid};

   my ($file, $io);

   if ($file = $args->{file} and $io = io($file) and $io->is_file) {
      push @{$pids}, $io->chomp->lock->getlines;
      unlink $file if $sig eq 'TERM';
   }

   throw 'Process id bad'
      unless defined $pids->[0] and $pids->[0] =~ m{ \d+ }mx;

   for my $mpid (@{$pids}) {
      if (exists $args->{flag} and $args->{flag} =~ m{ one }imx) {
         CORE::kill $sig, $mpid;
         next;
      }

      my @pids = reverse $self->child_list($mpid);

      CORE::kill $sig, $_ for (@pids);

      next unless $args->{force};

      sleep 3;
      @pids = reverse $self->child_list($mpid);

      CORE::kill 'KILL', $_ for (@pids);
   }

   return OK;
}

=item C<signal_process_as_root>

   $self->signal_process( [{] param => value, ... [}] );

This is called by processes running as root to send signals to
selected processes. The passed parameters can be either a list of key
value pairs or a hash ref. Either a single C<pid>, or an array ref
C<pids>, or C<file> must be passed. The C<file> parameter should be a
path to a file containing process ids one per line. The C<sig> defaults to
C<TERM>. If the C<flag> parameter is set to C<one> then the given signal
will be sent once to each selected process. Otherwise each process and
all of it's children will be sent the signal. If the C<force>
parameter is set to true the after a grace period each process and
it's children are sent signal C<KILL>

=cut

sub signal_process_as_root {
   my ($self, @args) = @_;

   return $self->signal_process(arg_list @args);
}

# Private methods
sub _new_process_table {
   my ($self, $rows, $count) = @_;

   return {
      count    => $count,
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
      wrap     => { cmd => 1 },
   };
}

# Private functions
sub _cmd_matches {
   my ($cmd, $pattern) = @_;

   return !$pattern || $cmd =~ m{ $pattern }msx ? TRUE : FALSE;
}

sub _new_proc_process_table {
   my $cache_ttys = shift;

   return Proc::ProcessTable->new( cache_ttys => $cache_ttys )
      if can_load( modules => { 'Proc::ProcessTable' => '0' } );

   return Class::Null->new;
}

sub _proc_belongs_to_user {
   my ($puid, $user) = @_;

   return (!$user || $user eq 'All' || $user eq loginid $puid) ? TRUE : FALSE;
}

sub _pscomp {
   my ($arg1, $arg2) = @_;

   my $result;

   $result = $arg1->{uid} cmp $arg2->{uid};
   $result = $arg1->{pid} <=> $arg2->{pid} if ($result == 0);

   return $result;
}

sub _set_fields {
   my ($has, $p) = @_;

   my $flds = {};

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

sub _signal_cmd {
   my ($cmd, $flag, $sig, $pids) = @_;

   my $opts = [];

   push @{$opts}, '-o', "sig=${sig}" if $sig;
   push @{$opts}, '-o', 'flag=one' if $flag;

   return [$cmd, '-c', 'signal_process', @{$opts}, '--', @{ $pids || [] }];
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Proc::ProcessTable>

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

Peter Flanigan, C<< <lazarus@roxsoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2023 Peter Flanigan. All rights reserved

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
