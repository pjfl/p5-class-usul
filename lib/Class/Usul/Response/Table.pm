# @(#)$Id$

package Class::Usul::Response::Table;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev$ =~ /\d+/gmx );

use Moose;

has 'align'    => is => 'rw', isa => 'HashRef',  default => sub { {} };
has 'class'    => is => 'rw', isa => 'Maybe[Str]';
has 'count'    => is => 'rw', isa => 'Int',      default => 0;
has 'flds'     => is => 'rw', isa => 'ArrayRef', default => sub { [] };
has 'hclass'   => is => 'rw', isa => 'HashRef',  default => sub { {} };
has 'labels'   => is => 'rw', isa => 'HashRef',  default => sub { {} };
has 'sizes'    => is => 'rw', isa => 'HashRef',  default => sub { {} };
has 'typelist' => is => 'rw', isa => 'HashRef',  default => sub { {} };
has 'values'   => is => 'rw', isa => 'ArrayRef', default => sub { [] };
has 'widths'   => is => 'rw', isa => 'HashRef',  default => sub { {} };
has 'wrap'     => is => 'rw', isa => 'HashRef',  default => sub { {} };

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

Class::Usul::Response::Table - Data structure for the table widget

=head1 Version

0.4.$Revision$

=head1 Synopsis

   use Class::Usul::Response;

   $table_object = Class::Usul::Response->new;

=head1 Description

Response class for the table widget in L<HTML::FormWidgets>. Defines a list
of mutable attributes

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Configuration and Environment

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

Copyright (c) 2008 Peter Flanigan. All rights reserved

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
