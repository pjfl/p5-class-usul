# @(#)$Id$

package Class::Usul::Constants;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

my @constants;

BEGIN {
   @constants = ( qw(ARRAY BRK CODE FAILED FALSE HASH LANG LOCALIZE LSB NUL
                     OK PHASE RSB SEP SPC TRUE UNTAINT_PATH_REGEX) );
}

use Sub::Exporter -setup => {
   exports => [ @constants ], groups => { default => [ @constants ], },
};

sub ARRAY    () { return q(ARRAY) }
sub BRK      () { return q(: )    }
sub CODE     () { return q(CODE)  }
sub FAILED   () { return 1        }
sub FALSE    () { return 0        }
sub HASH     () { return q(HASH)  }
sub LANG     () { return q(en)    }
sub LOCALIZE () { return q([_)    }
sub LSB      () { return q([)     }
sub NUL      () { return q()      }
sub OK       () { return 0        }
sub PHASE    () { return 2        }
sub RSB      () { return q(])     }
sub SEP      () { return q(/)     }
sub SPC      () { return q( )     }
sub TRUE     () { return 1        }

sub UNTAINT_PATH_REGEX () {
   return qr{ \A ([[:print:]]+) \z }mx;
}

1;

__END__

=pod

=head1 Name

Class::Usul::Constants - Definitions of constant values

=head1 Version

0.1.$Rev$

=head1 Synopsis

   use Class::Usul::Constants;

   my $bool = TRUE; my $slash = SEP;

=head1 Description

Exports a list of subroutines each of which returns a constants value

=head1 Subroutines/Methods

=head2 ARRAY

String ARRAY

=head2 BRK

Separate leader (: ) from message

=head2 CODE

String CODE

=head2 FAILED

Non zero exit code indicating program failure

=head2 FALSE

Digit 0

=head2 HASH

String HASH

=head2 LANG

Default language code

=head2 LOCALIZE

The character sequence that introduces a localization substitution
parameter

=head2 LSB

Left square bracket character

=head2 NUL

Empty string

=head2 OK

Returns good program exit code, zero

=head2 PHASE

The default phase number used to select installation specific config

=head2 RSB

Right square bracket character

=head2 SEP

Slash (/) character

=head2 SPC

Space character

=head2 TRUE

Digit 1

=head2 UNTAINT_PATH_REGEX

Regular expression used to untaint path strings

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<Sub::Exporter>

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
