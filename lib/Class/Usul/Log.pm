# @(#)$Id$

package Class::Usul::Log;

use strict;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Null;
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Constraints     qw(EncodingType LogType);
use Class::Usul::Functions       qw(merge_attributes);
use Encode;
use File::Basename               qw(dirname);
use File::DataClass::Constraints qw(Path);
use Log::Handler;

has '_debug_flag'     => is => 'ro', isa => Bool, init_arg => 'debug',
   default            => FALSE;

has '_encoding'       => is => 'ro', isa => Maybe[EncodingType],
   init_arg           => 'encoding';

has '_log'            => is => 'ro', isa => LogType, init_arg => 'log',
   builder            => '_build__log', lazy => TRUE;

has '_log_attributes' => is => 'ro', isa => HashRef,
   init_arg           => 'log_attributes', default => sub { {} };

has '_logfile'        => is => 'ro', isa => Path | Undef, coerce => TRUE,
   init_arg           => 'logfile';

around BUILDARGS => sub {
   my ($next, $class, @rest) = @_; my $attrs = $class->$next( @rest );

   my $builder = delete $attrs->{builder} or return $attrs;
   my $config  = $builder->can( q(config) ) ? $builder->config : {};

   merge_attributes $attrs, $builder, {}, [ qw(debug encoding) ];
   merge_attributes $attrs, $config,  {}, [ qw(log_attributes logfile) ];

   return $attrs;
};

sub BUILD {
   my $self = shift; my $class = blessed $self;

   my $meta = $class->meta; $meta->make_mutable;

   for my $method (LOG_LEVELS) {
      $meta->has_method( $method ) or $meta->add_method( $method => sub {
         my ($self, $text) = @_; $text or return;
         $self->_encoding and $text = encode( $self->_encoding, $text );
         $self->_log->$method( $text."\n" );
         return;
      } );
   }

   $meta->make_immutable;
   return;
}

# Private methods

sub _build__log {
   my $self    = shift;
   my $attrs   = { %{ $self->_log_attributes } };
   my $logfile = NUL.($attrs->{filename} || $self->_logfile);
   my $level   = $self->_debug_flag ? 7 : $attrs->{maxlevel} || 6;

   ($logfile and -d dirname( $logfile )) or return Class::Null->new;

   $attrs->{filename}   = $logfile;
   $attrs->{maxlevel}   = $level;
   $attrs->{mode    } ||= q(append);

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

   use Class::Usul::Constraints qw(LogType);
   use Class::Usul::Log;

   has '_log' => is => 'ro', isa => LogType,
      lazy    => TRUE,   builder => '_build__log',
      reader  => 'log', init_arg => 'log';

   sub _build__log {
      my $self = shift; return Class::Usul::Log->new( builder => $self );
   }

   # Can now call the following
   $self->log->debug( $text );
   $self->log->info(  $text );
   $self->log->warn(  $text );
   $self->log->error( $text );
   $self->log->fatal( $text );

=head1 Description

Creates methods for each logging level that encode their output. The
logging levels are defined by the
L<log levels|Class::Usul::Constants/LOG_LEVELS> constant

=head1 Configuration and Environment



=head1 Subroutines/Methods

=head2 BUILD

Creates a set of methods defined by the C<LOG_LEVELS> constant. The
method expects C<< $self->log >> and C<< $self->encoding >> to be set.
It encodes the output string prior calling the log method at the given
level

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Null>

=item L<Class::Usul::Constants>

=item L<Class::Usul::Constraints>

=item L<Class::Usul::Functions>

=item L<Class::Usul::Moose>

=item L<Encode>

=item L<File::DataClass::Constraints>

=item L<Log::Handler>

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
