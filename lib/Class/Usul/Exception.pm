# @(#)Ident: Exception.pm 2013-04-27 18:04 pjf ;

package Class::Usul::Exception;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev$ =~ /\d+/gmx );

use Exception::Class
   'Class::Usul::Exception::Base' => {
      fields => [ qw(args class leader out rv) ] };

use base qw(Class::Usul::Exception::Base);

use English      qw(-no_match_vars);
use List::Util   qw(first);
use MRO::Compat;
use Scalar::Util qw(blessed);

BEGIN {
   __PACKAGE__->mk_classdata
      ( 'Ignore', [ qw(Class::Usul::IPC File::DataClass::IO) ] );
   __PACKAGE__->mk_classdata( 'Min_Level', 2 );
}

sub new {
   my $self = shift; my $opts = __get_options( @_ ); my $error;

   __is_one_of_us( $error = delete $opts->{error} ) and return $error;

   my $leader = __get_leader( $opts ); $error .= q(); chomp $error;

   return $self->next::method( args           => [],
                               class          => __PACKAGE__,
                               error          => $error || 'Error unknown',
                               ignore_package => __PACKAGE__->Ignore(),
                               leader         => $leader,
                               out            => q(),
                               rv             => 1,
                               %{ $opts } );
}

sub catch {
   my ($self, @args) = @_; my $opts = __get_options( @args );

   my $error = $opts->{error} ||= $EVAL_ERROR; $error or return;

   return __is_one_of_us( $error ) ? $error : $self->new( $opts );
}

sub full_message {
   my $self = shift; my $text = $self->error or return;

   # Expand positional parameters of the form [_<n>]
   0 > index $text, q([_)  and return $self->leader.$text;

   my @args = map { defined $_ ? $_ : '[?]' } @{ $self->args },
              map { '[?]' } 0 .. 9;

   $text =~ s{ \[ _ (\d+) \] }{$args[ $1 - 1 ]}gmx;

   return $self->leader.$text;
}

sub stacktrace {
   my ($self, $skip) = @_; my ($l_no, @lines, %seen, $subr);

   for my $frame (reverse $self->trace->frames) {
      unless ($l_no = $seen{ $frame->package } and $l_no == $frame->line) {
         push @lines, join q( ), ($subr || $frame->package),
            'line', $frame->line;
         $seen{ $frame->package } = $frame->line;
      }

      $subr = $frame->subroutine;
   }

   defined $skip or $skip = 0; pop @lines while ($skip--);

   return wantarray ? reverse @lines : (join "\n", reverse @lines)."\n";
}

sub throw {
   my ($self, @args) = @_;

   die __is_one_of_us( $args[ 0 ] ) ? $args[ 0 ] : $self->new( @args );
}

sub throw_on_error {
   my ($self, @args) = @_;

   my $e; $e = $self->catch( @args ) and $self->throw( $e );

   return;
}

# Private subroutines

sub __get_leader {
   my $opts = shift; my ($leader, $line, $package);

   my $min =__PACKAGE__->Min_Level(); my $level = delete $opts->{level} || $min;

   do {
      ($package, $line) = (caller( $level ))[ 0, 2 ];
      $leader = "${package}[${line}][${level}]: "; $level++;
   }
   while (__is_member( $package, __PACKAGE__->Ignore()) );

   return $leader;
}

sub __get_options {
   return (__is_hashref( $_[ 0 ])) ? { %{ $_[ 0 ] } }
        :       (defined $_[ 1 ])  ? { @_ }
                                   : { error => $_[ 0 ] };
}

sub __is_arrayref {
   return $_[ 0 ] && ref $_[ 0 ] eq q(ARRAY) ? 1 : 0;
}

sub __is_hashref {
   return $_[ 0 ] && ref $_[ 0 ] eq q(HASH) ? 1 : 0;
}

sub __is_member {
   my ($candidate, @args) = @_; $candidate or return;

   __is_arrayref $args[ 0 ] and @args = @{ $args[ 0 ] };

   return (first { $_ eq $candidate } @args) ? 1 : 0;
}

sub __is_one_of_us {
   return $_[ 0 ] && blessed $_[ 0 ] && $_[ 0 ]->isa( __PACKAGE__ );
}

1;

__END__

=pod

=head1 Name

Class::Usul::Exception - Exception base class

=head1 Version

This documents version v0.15.$Rev$ of L<Class::Usul::Exception>

=head1 Synopsis

   use Class::Usul::Functions qw(throw);
   use Try::Tiny;

   sub some_method {
      my $self = shift;

      try   { this_will_fail }
      catch { throw $_ }
   }

   # OR

   use Class::Usul::Exception;

   sub some_method {
      my $self = shift;

      eval { this_will_fail };
      Class::Usul::Exception->throw_on_error;
   }

=head1 Description

Implements try (by way of an eval), throw, and catch error
semantics. Inherits from L<Exception::Class>

=head1 Configuration and Environment

The C<$Class::Usul::Exception::Ignore> package variable is an array ref of
methods whose presence should be suppressed in the stack trace output

The C<$Class::Usul::Exception::Min_Level> package variable defaults to C<3>.
It is the number of stack frames to skip before setting the error message
leader and line number

Defines the following list of attributes;

=over 3

=item C<args>

An array ref of parameters substituted in for the placeholders in the
error message when the error is localised

=item C<class>

Default to C<__PACKAGE__>. Can be used to differentiate different classes of
error

=item C<error>

The actually error message which defaults to C<Error unknown>. Can contain
placeholders of the form C<< [_<n>] >> where C<< <n> >> is an integer
starting at one

=item C<ignore_package>

Set to the value of the C<$Class::Usul::Exception::Ignore> package variable

=item C<leader>

Set to the package and line number where the error should be reported

=item C<out>

Defaults to null. May contain the output from whatever just threw the
exception

=item C<rv>

Return value which defaults to 1

=back

=head1 Subroutines/Methods

=head2 new

   $self = $class->new( @args );

Create an exception object. You probably do not want to call this directly,
but indirectly through L</catch>, L</throw>, or L</throw_on_error>

Calls the L</full_message> method if asked to serialize

=head2 catch

   $self = $class->catch( @args );

Catches and returns a thrown exception or generates a new exception if
C<$EVAL_ERROR> has been set. Returns either an exception object or undef

=head2 full_message

   $error_text = $self->full_message;

This is what the object stringifies to

=head2 stacktrace

   $lines = $self->stacktrace( $num_lines_to_skip );

Return the stack trace. Defaults to skipping one (the first) line of output

=head2 throw

   $class->throw error => 'Path [_1] not found', args => [ 'pathname' ];

Create (or re-throw) an exception to be caught by the catch above. If
the passed parameter is a blessed reference it is re-thrown. If a
single scalar is passed it is taken to be an error message code, a new
exception is created with all other parameters taking their default
values. If more than one parameter is passed the it is treated as a
list and used to instantiate the new exception. The 'error' parameter
must be provided in this case

=head2 throw_on_error

   $class->throw_on_error;

Calls L</catch> and if the was an exception L</throw>s it

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Exception::Class>

=item L<MRO::Compat>

=item L<Scalar::Util>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

The default ignore package list should be configurable

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan C<< <pjfl@cpan.org> >>

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
