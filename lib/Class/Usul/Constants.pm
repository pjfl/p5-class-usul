# @(#)$Id$

package Class::Usul::Constants;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

my @constants;

BEGIN {
   @constants = ( qw(ARRAY BRK CODE EXTNS FAILED FALSE HASH LANG
                     LOCALIZE LSB NO NUL OK PERMS PHASE PREFIX QUIT RSB SEP
                     SPC TRUE UNTAINT_PATH_REGEX WIDTH YES) );
}

use Sub::Exporter -setup => {
   exports => [ @constants ], groups => { default => [ @constants ], },
};

sub ARRAY    () { return q(ARRAY)            }
sub BRK      () { return q(: )               }
sub CODE     () { return q(CODE)             }
sub EXTNS    () { return  ( qw(.pl .pm .t) ) }
sub FAILED   () { return 1                   }
sub FALSE    () { return 0                   }
sub HASH     () { return q(HASH)             }
sub LANG     () { return q(en)               }
sub LOCALIZE () { return q([_)               }
sub LSB      () { return q([)                }
sub NO       () { return q(n)                }
sub NUL      () { return q()                 }
sub OK       () { return 0                   }
sub PERMS    () { return oct q(0660)         }
sub PHASE    () { return 2                   }
sub PREFIX   () { return [ NUL, q(opt) ]     }
sub QUIT     () { return q(q)                }
sub RSB      () { return q(])                }
sub SEP      () { return q(/)                }
sub SPC      () { return q( )                }
sub TRUE     () { return 1                   }
sub WIDTH    () { return 80                  }
sub YES      () { return q(y)                }

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

=head2 EXTNS

List of possible file suffixes used on Perl scripts

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

=head2 NO

The letter n

=head2 NUL

Empty string

=head2 OK

Returns good program exit code, zero

=head2 PERMS

Default file creation permissions

=head2 PHASE

The default phase number used to select installation specific config

=head2 PREFIX

Array ref representing the default parent path for a normal install

=head2 QUIT

The character q

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

=head2 WIDTH

Default terminal screen width in characters

=head2 YES

The character y

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
