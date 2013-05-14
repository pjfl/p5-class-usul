# @(#)$Ident: Table.pm 2013-04-29 19:26 pjf ;

package Class::Usul::Response::Table;

use version; our $VERSION = qv( sprintf '0.20.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use MooseX::Aliases;

has 'caption'  => is => 'ro', isa => Str,           default => q();
has 'class'    => is => 'ro', isa => HashRef | Str, default => q();
has 'classes'  => is => 'ro', isa => HashRef,       default => sub { {} };
has 'count'    => is => 'ro', isa => Int,           default => 0;
has 'fields'   => is => 'ro', isa => ArrayRef,      default => sub { [] },
   alias       => q(flds);
has 'hclass'   => is => 'ro', isa => HashRef,       default => sub { {} };
has 'labels'   => is => 'ro', isa => HashRef,       default => sub { {} };
has 'sizes'    => is => 'ro', isa => HashRef,       default => sub { {} };
has 'typelist' => is => 'ro', isa => HashRef,       default => sub { {} };
has 'values'   => is => 'ro', isa => ArrayRef,      default => sub { [] };
has 'widths'   => is => 'ro', isa => HashRef,       default => sub { {} };
has 'wrap'     => is => 'ro', isa => HashRef,       default => sub { {} };

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

Class::Usul::Response::Table - Data structure for the table widget

=head1 Version

This documents version v0.20.$Rev: 1 $

=head1 Synopsis

   use Class::Usul::Response::Table;

   $table_obj = Class::Usul::Response::Table->new( \%params );

=head1 Description

Response class for the table widget in L<HTML::FormWidgets>

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Moose>

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
