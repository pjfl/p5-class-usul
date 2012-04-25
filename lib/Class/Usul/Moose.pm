# @(#)$Id$

package Class::Usul::Moose;

use strict;
use warnings;
use feature ();
use namespace::autoclean ();
no  bareword::filehandles;
no  multidimensional;

#use Method::Signatures::Simple ();
use Moose ();
#use Moose::Autobox ();
use Moose::Util::TypeConstraints ();
use MooseX::Types::Moose ();
use MooseX::Types::Common::String ();
use MooseX::Types::Common::Numeric ();
use MooseX::Types::LoadableClass ();
# MooseX::Types::Parameterizable broken 0.08 RT#75119
#use MooseX::Types::Varchar ();

sub import {
   my ($self, @rest) = @_; my $into = caller;

   return _do_import( __PACKAGE__, $into, 'Moose', @rest );
}

# Private methods

sub _do_import {
   my ($class, $into, @also) = @_;

   my ( $import, $unimport, $init_meta )
      = Moose::Exporter->build_import_methods
         ( into => $into, also => [ @also, 'Moose::Util::TypeConstraints' ], );

   bareword::filehandles->unimport();
   multidimensional->unimport();
   feature->import( qw(state switch) );
   namespace::autoclean->import( -cleanee => $into );
   $class->$import( { into => $into } );
#   Method::Signatures::Simple->import( into => $into );
#   Moose::Autobox->import( into => $into );
   MooseX::Types::Moose->import( { into => $into },
      MooseX::Types::Moose->type_names );
   MooseX::Types::Common::String->import( { into => $into },
      MooseX::Types::Common::String->type_names );
   MooseX::Types::Common::Numeric->import( { into => $into },
      MooseX::Types::Common::Numeric->type_names );
   MooseX::Types::LoadableClass->import( { into => $into },
      qw(LoadableClass LoadableRole) );
#   MooseX::Types::Varchar->import( { into => $into }, 'Varchar' );
   return;
}

1;

__END__

=pod

=head1 Name

Class::Usul::Moose - Moose, the way I like it.

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use Class::Usul::Moose;

=head1 Description

Applies L<Moose>, L<Moose::Util::TypeConstraints>,
L<namespace::autoclean>, etc to the class using it.

=head1 Subroutines/Methods

=head2 import

Imports into the calling packages namespace the selected packages exports

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<bareword::filehandles>

=item L<feature>

=item L<namespace::autoclean>

=item L<multidimensional>

=item L<strict>

=item L<warnings>

=item L<Moose>

=item L<Moose::Util::TypeConstraints>

=item L<MooseX::Types::Moose>

=item L<MooseX::Types::Common::String>

=item L<MooseX::Types::Common::Numeric>

=item L<MooseX::Types::LoadableClass>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

t0m - Pasted his version of this, so I nicked it and adapted

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
