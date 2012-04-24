# @(#)$Id$

package Class::Usul::Log;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use Class::Null;
use Class::Usul::Constants;
use Class::Usul::Constraints     qw(EncodingType LogType);
use Class::Usul::Functions       qw(merge_attributes);
use Encode;
use File::Basename               qw(dirname);
use File::DataClass::Constraints qw(Path);
use Log::Handler;
use MooseX::Types::Moose         qw(Bool HashRef Maybe);
use Scalar::Util                 qw(blessed);

has 'debug'          => is => 'ro', isa  => Bool,    default => FALSE;

has 'encoding'       => is => 'ro', isa  => Maybe[EncodingType];

has 'log'            => is => 'ro', isa  => LogType, lazy    => TRUE,
   builder           => '_build_log';

has 'log_attributes' => is => 'ro', isa  => HashRef, default => sub { {} };

has 'logfile'        => is => 'ro', isa  => Maybe[Path];

around 'BUILDARGS' => sub {
   my ($next, $class, @rest) = @_; my $attrs = $class->$next( @rest );

   my $ioc = delete $attrs->{ioc} or return $attrs;

   merge_attributes $attrs, $ioc,         {}, [ qw(debug encoding) ];
   merge_attributes $attrs, $ioc->config, {}, [ qw(log_attributes logfile) ];

   return $attrs;
};

sub BUILD {
   my $self = shift; my $class = blessed $self || $self;

   my $meta = $class->meta; $meta->make_mutable;

   for my $method (LOG_LEVELS) {
      $meta->has_method( $method ) or $meta->add_method( $method => sub {
         my ($self, $text) = @_; $text or return;
         $self->encoding and $text = encode( $self->encoding, $text );
         $self->log->$method( $text."\n" );
         return;
      } );
   }

   $meta->make_immutable;
   return;
}

# Private methods

sub _build_log {
   my $self    = shift;
   my $attrs   = { %{ $self->log_attributes } };
   my $logfile = NUL.($attrs->{filename} || $self->logfile);
   my $level   = $self->debug ? 7 : $attrs->{maxlevel} || 6;

   ($logfile and -d dirname( $logfile )) or return Class::Null->new;

   $attrs->{filename} = $logfile; $attrs->{maxlevel} = $level;

   $attrs->{mode} ||= q(append);

   return Log::Handler->new( file => $attrs );
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

Class::Usul::Log - Create methods for each logging level that encode their output

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use Moose;
   use Log::Handler;

   has 'encoding' => is => 'ro', isa => 'Str', default => q(UTF-8);

   has 'log'      => is => 'ro', isa => 'Object',
      default     => sub { Log::Handler->new };

   with qw(Class::Usul::DoesLoggingLevels);

   # Can now call the following
   $self->log_debug( $text );
   $self->log_info(  $text );
   $self->log_warn(  $text );
   $self->log_error( $text );
   $self->log_fatal( $text );

=head1 Description

A L<Moose Role|Moose::Role> that creates methods for each logging
level that encode their output. The logging levels are defined by the
L<log levels|Class::Usul::Constants/LOG_LEVELS> constant

=head1 Configuration and Environment

This role requires the attributes; I<encoding> and I<log>

=head1 Subroutines/Methods

=head2 import

Called when the role is applied to a class. It creates a set of
methods defined by the C<LOG_LEVELS> constant. The method expects C<<
$self->log >> and C<< $self->encoding >> to be set.  It encodes the
output string prior calling the log method at the given level

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Null>

=item L<Class::Usul::Constants>

=item L<Encode>

=item L<Moose::Role>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2012 Peter Flanigan. All rights reserved

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
