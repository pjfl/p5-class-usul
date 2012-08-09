# @(#)$Id$

package Class::Usul::Constraints;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Encode                      qw(find_encoding);
use Class::Load                 qw(load_first_existing_class);
use Class::Usul::Constants;
use Class::Usul::Functions;
use MooseX::Types -declare => [ qw(BaseType ClassName ConfigType EncodingType
                                   FileType IPCType L10NType LockType LogType
                                   NullLoadingClass RequestType) ];
use MooseX::Types::Moose        qw(HashRef Object Str Undef),
                 ClassName => { -as => 'MooseClassName' };
use Scalar::Util                qw(blessed);

class_type BaseType, { class => 'Class::Usul'       };
class_type FileType, { class => 'Class::Usul::File' };
class_type IPCType,  { class => 'Class::Usul::IPC'  };

subtype ConfigType, as Object,
   where   { blessed $_ and __has_min_config_attributes( $_ ) },
   message { blessed $_
                ? 'Object '.(blessed $_).' is missing some config attributes'
                : "Scalar ${_} is not on object reference" };

subtype EncodingType, as Str,
   where   { find_encoding( $_ ) },
   message { "String ${_} is not a valid encoding" };
coerce  EncodingType, from Undef, via { DEFAULT_ENCODING };

subtype L10NType, as Object,
   where   { blessed $_ and $_->can( q(localize) ) },
   message { blessed $_
                ? 'Object '.(blessed $_).' is missing the localize method'
                : "Scalar ${_} is not on object reference" };

subtype LockType, as Object,
   where   { blessed $_ and $_->can( q(set) ) and $_->can( q(reset) ) },
   message { blessed $_
                ? 'Object '.(blessed $_).' is missing set / reset method'
                : "Scalar ${_} is not on object reference" };

subtype LogType, as Object,
   where   { $_->isa( q(Class::Null) ) or __has_log_level_methods( $_ ) },
   message { 'Object '.(blessed $_ || $_).' is missing a log level method' };

subtype NullLoadingClass, as MooseClassName;
coerce  NullLoadingClass,
   from Str,   via { __load_if_exists( $_  ) },
   from Undef, via { __load_if_exists( NUL ) };

subtype RequestType, as Object,
   where   { $_->can( q(params) ) },
   message { 'Object '.(blessed $_ || $_).' is missing a params method' };

sub __has_log_level_methods {
   my $obj = shift;

   $obj->can( $_ ) or return FALSE for (LOG_LEVELS);

   return TRUE;
}

sub __has_min_config_attributes {
   my $obj  = shift;

   ($obj->can( q(meta) ) and $obj->meta->can( q(get_attribute_list) ))
      or return FALSE;

   my $attr = { map { $_ => 1 } $obj->meta->get_attribute_list };

   my @config_attr = ( qw(appldir home root tempdir vardir) );

   exists $attr->{ $_ } or return FALSE for (@config_attr);

   return TRUE;
}

sub __load_if_exists {
   my $name = shift; load_first_existing_class( $name, q(Class::Null) );
};

1;

__END__

=pod

=head1 Name

Class::Usul::Constraints - Defines Moose type constraints

=head1 Version

This document describes Class::Usul::Constraints version 0.1.$Revision$

=head1 Synopsis

   use Class::Usul::Constraints q(:all);

=head1 Description

Defines the following type constraints

=over 3

=item ConfigType

Subtype of I<Object> can be coerced from a hash ref

=item EncodingType

Subtype of I<Str> which has to be one of the list of encodings in the
I<ENCODINGS> constant

=item LogType

Subtype of I<Object> which has to implement all of the methods in the
I<LOG_LEVELS> constant

=back

=head1 Subroutines/Methods

None

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Constants>

=item L<Class::Usul::Functions>

=item L<MooseX::Types>

=item L<MooseX::Types::Moose>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 Acknowledgements

Larry Wall - For the Perl programming language

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

