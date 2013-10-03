# @(#)$Ident: Types.pm 2013-09-29 16:31 pjf ;

package Class::Usul::Types;

use strict;
use warnings;
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.28.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Load             qw( load_first_existing_class );
use Class::Usul::Constants;
use Encode                  qw( find_encoding );
use Scalar::Util            qw( blessed );
use Type::Library              -base, -declare =>
                            qw( BaseType ConfigType EncodingType
                                FileType IPCType L10NType LockType
                                LogType NullLoadingClass PromptType
                                RequestType );
use Type::Utils             qw( as class_type coerce extends
                                from message subtype via where );
use Unexpected::Functions   qw( inflate_message );

BEGIN { extends q(Unexpected::Types) };

class_type BaseType,   { class => 'Class::Usul'         };
class_type FileType,   { class => 'Class::Usul::File'   };
class_type IPCType,    { class => 'Class::Usul::IPC'    };
class_type PromptType, { class => 'Class::Usul::Prompt' };

subtype ConfigType, as Object,
   where   { __has_min_config_attributes( $_ ) },
   message { __exception_message_for_configtype( $_ ) };

subtype EncodingType, as Str,
   where   { find_encoding( $_ ) },
   message { inflate_message( 'String [_1] is not a valid encoding', $_ ) };

subtype L10NType, as Object,
   where   { $_->can( 'localize' ) },
   message { __exception_message_for_l10ntype( $_ ) };

subtype LockType, as Object,
   where   { $_->can( 'set' ) and $_->can( 'reset' ) },
   message { __exception_message_for_locktype( $_ ) };

subtype LogType, as Object,
   where   { $_->isa( 'Class::Null' ) or __has_log_level_methods( $_ ) },
   message { __exception_message_for_logtype( $_ ) };

subtype NullLoadingClass, as ClassName;

subtype RequestType, as Object,
   where   { $_->can( 'params' ) },
   message { __exception_message_for_requesttype( $_ ) };

coerce EncodingType, from Undef, via { DEFAULT_ENCODING };

coerce NullLoadingClass,
   from Str,   via { __load_if_exists( $_  ) },
   from Undef, via { __load_if_exists( NUL ) };

# Private functions
sub __exception_message_for_configtype {
   blessed $_[ 0 ] and return inflate_message
      ( 'Object [_1] is missing some config attributes', blessed $_[ 0 ] );

   return __exception_message_for_object_reference( $_[ 0 ] );
}

sub __exception_message_for_l10ntype {
   blessed $_[ 0 ] and return inflate_message
      ( 'Object [_1] is missing the localize method', blessed $_[ 0 ] );

   return __exception_message_for_object_reference( $_[ 0 ] );
}

sub __exception_message_for_locktype {
   blessed $_[ 0 ] and return inflate_message
      ( 'Object [_1] is missing set / reset methods', blessed $_[ 0 ] );

   return __exception_message_for_object_reference( $_[ 0 ] );
}

sub __exception_message_for_logtype {
   blessed $_[ 0 ] and return inflate_message
      ( 'Object [_1] is missing a log level method', blessed $_[ 0 ] );

   return __exception_message_for_object_reference( $_[ 0 ] );
}

sub __exception_message_for_object_reference {
   return inflate_message( 'String [_1] is not an object reference', $_[ 0 ] );
}

sub __exception_message_for_requesttype {
   blessed $_[ 0 ] and return inflate_message
      ( 'Object [_1] is missing a params method', blessed $_[ 0 ] );

   return __exception_message_for_object_reference( $_[ 0 ] );
}

sub __has_log_level_methods {
   my $obj = shift;

   $obj->can( $_ ) or return FALSE for (LOG_LEVELS);

   return TRUE;
}

sub __has_min_config_attributes {
   my $obj = shift; my @config_attr = ( qw(appldir home root tempdir vardir) );

   $obj->can( $_ ) or return FALSE() for (@config_attr);

   return TRUE();
}

sub __load_if_exists {
   my $name = shift; load_first_existing_class( $name, q(Class::Null) );
};

1;

__END__

=pod

=head1 Name

Class::Usul::Types - Defines type constraints

=head1 Version

This document describes Class::Usul::Types version v0.28.$Rev: 1 $

=head1 Synopsis

   use Class::Usul::Types q(:all);

=head1 Description

Defines the following type constraints

=over 3

=item C<ConfigType>

Subtype of I<Object> can be coerced from a hash ref

=item C<EncodingType>

Subtype of I<Str> which has to be one of the list of encodings in the
I<ENCODINGS> constant

=item C<LogType>

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

=item L<Type::Tiny>

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

