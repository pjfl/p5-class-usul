# @(#)$Id$

package Class::Usul::Base;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose::Role;
use Class::Usul::Constants;
use Class::Usul::Functions qw(data_dumper throw);
use Class::MOP;
use Try::Tiny;

sub dumper {
   my $self = shift; return data_dumper( @_ ); # Damm handy for development
}

sub ensure_class_loaded {
   my ($self, $class, $opts) = @_; $opts ||= {};

   my $package_defined = sub { Class::MOP::is_class_loaded( $class ) };

   not $opts->{ignore_loaded} and $package_defined->() and return TRUE;

   try { Class::MOP::load_class( $class ) } catch { throw $_ }

   $package_defined->()
      or throw error => 'Class [_1] loaded but package undefined',
               args  => [ $class ];

   return TRUE;
}

sub load_component {
   my ($self, $child, @parents) = @_;

   ## no critic
   for my $parent (reverse @parents) {
      $self->ensure_class_loaded( $parent );
      {  no strict q(refs);

         $child eq $parent or $child->isa( $parent )
            or unshift @{ "${child}::ISA" }, $parent;
      }
   }

   exists $Class::C3::MRO{ $child } or eval "package $child; import Class::C3;";
   ## critic
   return;
}

sub supports {
   my ($self, @spec) = @_; my $cursor = eval { $self->get_features } || {};

   @spec == 1 and exists $cursor->{ $spec[ 0 ] } and return TRUE;

   # Traverse the feature list
   for (@spec) {
      ref $cursor eq HASH or return FALSE; $cursor = $cursor->{ $_ };
   }

   ref $cursor or return $cursor; ref $cursor eq ARRAY or return FALSE;

   # Check that all the keys required for a feature are in here
   for (@{ $cursor }) { exists $self->{ $_ } or return FALSE }

   return TRUE;
}

no Moose::Role;

1;

__END__

=pod

=head1 Name

Class::Usul::Base - Base class utility methods

=head1 Version

0.1.$Revision$

=head1 Synopsis

   package MyBaseClass;

   use Moose;

   extends qw(Class::Usul::Base);

=head1 Description

Provides utility methods to the application base class

=head1 Subroutines/Methods

=head2 ensure_class_loaded

   $self->ensure_class_loaded( $some_class );

Require the requested class, throw an error if it doesn't load

=head2 load_component

   $self->load_component( $child, @parents );

Ensures that each component is loaded then fixes @ISA for the child so that
it inherits from the parents

=head2 supports

   $bool = $self->supports( @spec );

Returns true if the hash returned by our I<get_features> attribute
contains all the elements of the required specification

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Constants>

=item L<Class::MOP>

=back

=head1 Incompatibilities

None

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

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
