# @(#)$Id$

package Class::Usul::Constants;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

my @constants;

BEGIN {
   @constants = ( qw(ARRAY BRK CODE ENCODINGS EXTNS FAILED FALSE HASH
                     LANG LOCALIZE LOG_LEVELS LSB NO NUL OK PERMS
                     PHASE PREFIX QUIT RSB SEP SPC TRUE
                     UNTAINT_PATH_REGEX WIDTH YES) );
}

use Sub::Exporter -setup => {
   exports => [ @constants ], groups => { default => [ @constants ], },
};

sub ARRAY      () { q(ARRAY)            }
sub BRK        () { q(: )               }
sub CODE       () { q(CODE)             }
sub ENCODINGS  () { ( qw(ascii iso-8859-1 UTF-8 guess) ) }
sub EXTNS      () { ( qw(.pl .pm .t) )  }
sub FAILED     () { 1                   }
sub FALSE      () { 0                   }
sub HASH       () { q(HASH)             }
sub LANG       () { q(en)               }
sub LOCALIZE   () { q([_)               }
sub LOG_LEVELS () { ( qw(alert debug error fatal info warn) ) }
sub LSB        () { q([)                }
sub NO         () { q(n)                }
sub NUL        () { q()                 }
sub OK         () { 0                   }
sub PERMS      () { oct q(0660)         }
sub PHASE      () { 2                   }
sub PREFIX     () { [ NUL, q(opt) ]     }
sub QUIT       () { q(q)                }
sub RSB        () { q(])                }
sub SEP        () { q(/)                }
sub SPC        () { q( )                }
sub TRUE       () { 1                   }
sub WIDTH      () { 80                  }
sub YES        () { q(y)                }

sub UNTAINT_PATH_REGEX () { qr{ \A ([[:print:]]+) \z }mx }

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

=head2 ENCODINGS

List of supported IO encodings

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

=head2 LOG_LEVELS

List of methods the log object is expected to support

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
