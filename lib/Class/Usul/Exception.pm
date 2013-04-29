# @(#)Ident: Exception.pm 2013-04-29 02:39 pjf ;

package Class::Usul::Exception;

# Package namespace::autoclean does not play nice with overload
use namespace::clean -except => 'meta';
use overload '""' => sub { shift->as_string }, fallback => 1;
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use MooseX::ClassAttribute;
use MooseX::AttributeShortcuts;
use MooseX::Types     -declare => [ q(StackTrace) ];
use MooseX::Types::Common::String  qw(NonEmptySimpleStr SimpleStr);
use MooseX::Types::Common::Numeric qw(PositiveInt);
use MooseX::Types::LoadableClass   qw(LoadableClass);
use MooseX::Types::Moose           qw(ArrayRef HashRef Int Object);
use English                        qw(-no_match_vars);
use List::Util                     qw(first);
use Scalar::Util                   qw(weaken);

# Type constraints
subtype StackTrace, as Object,
   where   { $_->can( q(frames) ) },
   message { blessed $_ ? 'Object '.(blessed $_).' is missing a frames method'
                        : "Scalar ${_} is not on object reference" };

# Class attributes
class_has 'Ignore' => is => 'rw',   isa => ArrayRef,
   default         => sub { [ qw(Class::Usul::IPC File::DataClass::IO) ] };

# Object attributes (public)
has 'args'         => is => 'ro',   isa => ArrayRef, default => sub { [] };

has 'class'        => is => 'ro',   isa => NonEmptySimpleStr,
   default         => __PACKAGE__;

has 'error'        => is => 'ro',   isa => NonEmptySimpleStr,
   default         => 'Unknown error';

has 'leader'       => is => 'lazy', isa => NonEmptySimpleStr;

has 'level'        => is => 'ro',   isa => PositiveInt, default => 1;

has 'out'          => is => 'ro',   isa => SimpleStr, default => q();

has 'rv'           => is => 'ro',   isa => Int, default => 1;

has 'time'         => is => 'ro',   isa => PositiveInt, default => CORE::time();

has 'trace'        => is => 'lazy', isa => StackTrace,
   handles         => [ qw(frames) ], init_arg => undef;

has 'trace_args'   => is => 'lazy', isa => HashRef;

has 'trace_class'  => is => 'ro',   isa => LoadableClass, coerce => 1,
   default         => sub { q(Devel::StackTrace) };

around 'BUILDARGS' => sub {
   my ($next, $self, @args) = @_; my $attr = __get_attr( @args );

   $attr->{error} and $attr->{error} .= q() and chomp $attr->{error};

   return $attr;
};

sub BUILD {
   my $self = shift; $self->trace; return;
}

sub as_string {
   my $self = shift; my $text = $self->error or return;

   # Expand positional parameters of the form [_<n>]
   0 > index $text, q([_)  and return $self->leader.$text;

   my @args = map { $_ // '[?]' } @{ $self->args }, map { '[?]' } 0 .. 9;

   $text =~ s{ \[ _ (\d+) \] }{$args[ $1 - 1 ]}gmx;

   return $self->leader.$text;
}

sub caught {
   my ($self, @args) = @_; my $attr = __get_attr( @args );

   my $error = $attr->{error} ||= $EVAL_ERROR; $error or return;

   return __is_one_of_us( $error ) ? $error : $self->new( $attr );
}

sub stacktrace {
   my ($self, $skip) = @_; my ($l_no, @lines, %seen, $subr);

   for my $frame (reverse $self->frames) {
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
   my ($self, @args) = @_; my $e;

   $e = $self->caught( @args ) and $self->throw( $e );

   return;
}

sub trace_frame_filter { # Lifted from StackTrace::Auto
   my $self = shift; my $found_mark = 0; weaken( $self );

   return sub {
      my ($raw)    = @_;
      my  $sub     = $raw->{caller}->[ 3 ];
     (my  $package = $sub) =~ s{ :: \w+ \z }{}mx;

      if    ($found_mark == 3) { return 1 }
      elsif ($found_mark == 2) {
         $sub =~ m{ ::new \z }mx and $self->isa( $package ) and return 0;
         $found_mark++; return 1;
      }
      elsif ($found_mark == 1) {
         $sub =~ m{ ::new \z }mx and $self->isa( $package ) and $found_mark++;
         return 0;
      }

      $raw->{caller}->[ 3 ] =~ m{ ::_build_trace \z }mx and $found_mark++;
      return 0;
   }
}

# Private methods
sub _build_leader {
   my $self = shift; my $level = $self->level;

   my @frames = $self->frames; my ($leader, $line, $package);

   do {
      if ($package = $frames[ $level ]->package) {
         $line   = $frames[ $level ]->line;
         $leader = "${package}[${line}][${level}]: "; $level++;
      }
      else { $leader = $package = q() }
   }
   while ($package and __is_member( $package, __PACKAGE__->Ignore()) );

   return $leader;
}

sub _build_trace {
   return $_[ 0 ]->trace_class->new( %{ $_[ 0 ]->trace_args } );
}

sub _build_trace_args {
   return { no_refs          => 1,
            respect_overload => 0,
            max_arg_length   => 0,
            frame_filter     => $_[ 0 ]->trace_frame_filter, };
}

# Private functions
sub __get_attr {
   return ($_[ 0 ] && ref $_[ 0 ] eq q(HASH)) ? { %{ $_[ 0 ] } }
        : (defined $_[ 1 ])                   ? { @_ }
                                              : { error => $_[ 0 ] };
}

sub __is_member {
   my ($candidate, @args) = @_; $candidate or return;

   $args[ 0 ] && ref $args[ 0 ] eq q(ARRAY) and @args = @{ $args[ 0 ] };

   return (first { $_ eq $candidate } @args) ? 1 : 0;
}

sub __is_one_of_us {
   return $_[ 0 ] && blessed $_[ 0 ] && $_[ 0 ]->isa( __PACKAGE__ );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

Class::Usul::Exception - Exception handling

=head1 Version

This documents version v0.15.$Rev$ of L<Class::Usul::Exception>

=head1 Synopsis

   use Class::Usul::Functions qw(throw);
   use Try::Tiny;

   sub some_method {
      my $self = shift;

      try   { this_will_fail }
      catch { throw $_ };
   }

   # OR
   use Class::Usul::Exception;

   sub some_method {
      my $self = shift;

      eval { this_will_fail };
      Class::Usul::Exception->throw_on_error;
   }

   # THEN
   try   { $self->some_method() }
   catch { warn $_."\n\n".$_->stacktrace."\n" };

=head1 Description

An exception class that supports error messages with placeholders, a
L</throw> method with automatic re-throw upon detection of self,
conditional throw if an exception was caught and a simplified
stacktrace

=head1 Configuration and Environment

The C<$Class::Usul::Exception::Ignore> package variable is an array ref of
methods whose presence should be ignored by the error message leader

Defines the following list of read only attributes;

=over 3

=item C<args>

An array ref of parameters substituted in for the placeholders in the
error message when the error is localised

=item C<class>

Defaults to C<__PACKAGE__>. Can be used to differentiate different classes of
error

=item C<error>

The actually error message which defaults to C<Unknown error>. Can contain
placeholders of the form C<< [_<n>] >> where C<< <n> >> is an integer
starting at one

=item C<leader>

Set to the package and line number where the error should be reported

=item C<level>

A positive integer which defaults to one. How many additional stack frames
to pop before calculating the C<leader> attribute

=item C<out>

Defaults to null. May contain the output from whatever just threw the
exception

=item C<rv>

Return value which defaults to one

=item C<time>

A positive integer which defaults to the C<CORE::time> the exception was
thrown

=item C<trace>

An instance of the C<trace_class>

=item C<trace_args>

A hash ref of arguments passed the C<trace_class> constructor when the
C<trace> attribute is instantiated

=item C<trace_class>

A loadable class which defaults to L<Devel::StackTrace>

=back

=head1 Subroutines/Methods

=head2 BUILD

Forces the instantiation of the C<trace> attribute

=head2 as_string

   $error_text = $self->as_string;

This is what the object stringifies to, including the C<leader> attribute

=head2 caught

   $self = $class->caught( [ @args ] );

Catches and returns a thrown exception or generates a new exception if
C<$EVAL_ERROR> has been set. Returns either an exception object or undef

=head2 stacktrace

   $lines = $self->stacktrace( $num_lines_to_skip );

Return the stack trace. Defaults to skipping zero lines of output

=head2 throw

   $class->throw error => 'Path [_1] not found', args => [ 'pathname' ];

Create (or re-throw) an exception. If the passed parameter is a
blessed reference it is re-thrown. If a single scalar is passed it is
taken to be an error message, a new exception is created with all
other parameters taking their default values. If more than one
parameter is passed the it is treated as a list and used to
instantiate the new exception. The 'error' parameter must be provided
in this case

=head2 throw_on_error

   $class->throw_on_error( [ @args ] );

Calls L</caught> passing in the options C<@args> and if there was an
exception L</throw>s it

=head2 trace_from_filter

Lifted from L<StackTrace::Auto> this methods filters out frames from the
raw stacktrace that are not of interest. If is very clever

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<namespace::clean>

=item L<overload>

=item L<Devel::StackTrace>

=item L<List::Util>

=item L<Moose>

=item L<MooseX::ClassAttribute>

=item L<MooseX::AttributeShortcuts>

=item L<MooseX::Types>

=item L<MooseX::Types::Common::String>

=item L<MooseX::Types::Common::Numeric>

=item L<MooseX::Types::LoadableClass>

=item L<MooseX::Types::Moose>

=item L<Scalar::Util>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

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
