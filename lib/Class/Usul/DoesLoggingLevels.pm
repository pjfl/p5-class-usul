# @(#)$Id$

package Class::Usul::DoesLoggingLevels;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose::Role;
use Class::Usul::Constants;
use Scalar::Util qw(blessed);
use Encode;

requires qw(encoding log);

sub import {
   my $self = shift; my $class = blessed $self || $self;

   $class->meta->make_mutable;

   for my $level (LOG_LEVELS) {
      my $method = q(log_).$level;

      $class->meta->has_method( $method ) and next;
      $class->meta->add_method( $method => sub {
         my ($self, $text) = @_; $text or return;
         $self->encoding and $text = encode( $self->encoding, $text );
         $self->log->$level( $text."\n" );
         return;
      } );
   }

   $class->meta->make_immutable;
   return;
}

no Moose::Role;

1;

__END__

=pod

=head1 Name

Class::Usul::DoesLoggingLevels - Create methods for each logging level that encode their output

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use Moose;

   has 'encoding'   => is => 'ro',    isa => 'Str',
      documentation => 'Decode/encode input/output using this encoding',
      lazy          => TRUE,      builder => '_build_encoding';

   has '_log'       => is => 'ro',    isa => 'Object',
      lazy          => TRUE,      builder => '_build__log',
      reader        => 'log',    init_arg => 'log';

   with qw(Class::Usul::DoesLoggingLevels);

=head1 Description

A L<Moose Role|Moose::Role> that creates methods for each logging
level that encode their output. The logging levels are defined by the
L<log levels|Class::Usul::Constants/LOG_LEVELS> constant

=head1 Configuration and Environment

This role requires the attributes; I<encoding> and I<log>

=head1 Subroutines/Methods

=head2 import

Called when the role is applied to a class

=head1 Diagnostics

None

=head1 Dependencies

=over 3

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
