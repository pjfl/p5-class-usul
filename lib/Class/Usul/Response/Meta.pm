# @(#)$Id$

package Class::Usul::Response::Meta;

use version; our $VERSION = qv( sprintf '0.11.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Moose;
use YAML::Syck;

has 'abstract' => is => 'ro', isa => 'Maybe[Str]';
has 'author'   => is => 'ro', isa => 'Maybe[ArrayRef]';
has 'license'  => is => 'ro', isa => 'Maybe[Str]';
has 'name'     => is => 'ro', isa => 'Maybe[Str]';
has 'provides' => is => 'ro', isa => 'Maybe[HashRef]';
has 'version'  => is => 'ro', isa => 'Maybe[Str]';

around 'BUILDARGS' => sub {
   return LoadFile( q().$_[2] ) || {};
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

Class::Usul::Response::Meta - Class for CPAN Meta file

=head1 Version

This document describes Class::Usul::Response::Meta version 0.11.$Revision$

=head1 Synopsis

   use Class::Usul::Response::Meta;

   Class::Usul::Response::Meta->new( $path_to_meta_yaml_file );

=head1 Description

Uses L<YAML::Syck> to load the specified YAML file and returns on object
which define accessors for it's attributes

=head1 Subroutines/Methods

None

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moose>

=item L<YAML::Syck>

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
