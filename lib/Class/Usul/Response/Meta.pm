# @(#)$Id$

package Class::Usul::Response::Meta;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use YAML::Syck;

has 'abstract' => is => 'ro', isa => 'Maybe[Str]';
has 'author'   => is => 'ro', isa => 'Maybe[ArrayRef]';
has 'license'  => is => 'ro', isa => 'Maybe[Str]';
has 'name'     => is => 'ro', isa => 'Maybe[Str]';
has 'provides' => is => 'ro', isa => 'Maybe[HashRef]';
has 'version'  => is => 'ro', isa => 'Maybe[Str]';

around BUILDARGS => sub {
   return $_[2] && -f $_[2] ? LoadFile( $_[2] ) : {};
};

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

Class::Usul::Response::Meta - Class for CPAN Meta file

=head1 Version

This document describes Class::Usul::Response::Meta version 0.1.$Revision$

=head1 Synopsis

=head1 Description

=head1 Subroutines/Methods

=head1 Configuration and Environment

None

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

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
