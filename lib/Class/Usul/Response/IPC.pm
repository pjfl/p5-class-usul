# @(#)$Id$

package Class::Usul::Response::IPC;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose;

has 'core'   => is => 'rw', isa => 'Int', default => 0;
has 'out'    => is => 'rw', isa => 'Str', default => q();
has 'pid'    => is => 'rw', isa => 'Maybe[Int]';
has 'rv'     => is => 'rw', isa => 'Int', default => 0;
has 'sig'    => is => 'rw', isa => 'Maybe[Int]';
has 'stderr' => is => 'rw', isa => 'Str', default => q();
has 'stdout' => is => 'rw', isa => 'Str', default => q();

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

Class::Usul::Response::IPC - Response class for running external programs

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use Class::Usul::IPC::Response;

   my $result = Class::Usul::IPC::Response->new();

=head1 Description

Response class returned by L<Class::Usul::IPC/run_cmd> and
L<Class::Usul::IPC/popen>

=head1 Configuration and Environment

This class defined these attributes:

=over 3

=item core

True if external commands core dumped

=item out

Processed output from the command

=item sig

Signal that caused the program to terminate

=item stderr

The standard error output from the command

=item stdout

The standard output from the command

=back

=head1 Subroutines/Methods

=head2 new

Basic constructor

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Base>

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

Copyright (c) 2010 Peter Flanigan. All rights reserved

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
