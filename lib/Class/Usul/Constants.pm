# @(#)$Id$

package Class::Usul::Constants;

use strict;
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use MooseX::ClassAttribute;
use File::DataClass::Exception;
use File::DataClass::Constants ();

class_has 'Assert'          => is => 'rw', isa => 'Maybe[CodeRef]';

class_has 'Config_Extn'     => is => 'rw', isa => 'Str',
   default                  => q(.json);

class_has 'Exception_Class' => is => 'rw', isa => 'File::DataClass::Exception',
   default                  => q(File::DataClass::Exception);

my @constants;

BEGIN {
   @constants = ( qw(ARRAY ASSERT BRK CODE CONFIG_EXTN DEFAULT_DIR
                     DEFAULT_ENCODING DEFAULT_L10N_DOMAIN
                     DIGEST_ALGORITHMS ENCODINGS EVIL EXCEPTION_CLASS EXTNS
                     FAILED FALSE HASH LANG LBRACE LOCALIZE LOG_LEVELS
                     NO NUL OK PERMS PHASE PREFIX QUIT SEP SPC TRUE
                     UNTAINT_CMDLINE UNTAINT_IDENTIFIER UNTAINT_PATH
                     UUID_PATH WIDTH YES) );
}

use Sub::Exporter -setup => {
   exports => [ @constants ], groups => { default => [ @constants ], },
};

sub ARRAY    () { q(ARRAY)           }
sub BRK      () { q(: )              }
sub CODE     () { q(CODE)            }
sub EVIL     () { q(MSWin32)         }
sub EXTNS    () { ( qw(.pl .pm .t) ) }
sub FAILED   () { 1                  }
sub FALSE    () { 0                  }
sub HASH     () { q(HASH)            }
sub LANG     () { q(en)              }
sub LBRACE   () { q({)               }
sub LOCALIZE () { q([_)              }
sub NO       () { q(n)               }
sub NUL      () { q()                }
sub OK       () { 0                  }
sub PERMS    () { oct q(0660)        }
sub PHASE    () { 2                  }
sub PREFIX   () { [ NUL, q(opt) ]    }
sub QUIT     () { q(q)               }
sub SEP      () { q(/)               }
sub SPC      () { q( )               }
sub TRUE     () { 1                  }
sub WIDTH    () { 80                 }
sub YES      () { q(y)               }

sub ASSERT              () { __PACKAGE__->Assert || sub {} }
sub CONFIG_EXTN         () { __PACKAGE__->Config_Extn }
sub DEFAULT_DIR         () { [ NUL, qw(etc default) ] }
sub DEFAULT_ENCODING    () { q(UTF-8) }
sub DEFAULT_L10N_DOMAIN () { q(default) }
sub DIGEST_ALGORITHMS   () { ( qw(SHA-512 SHA-256 SHA-1 MD5) ) }
sub ENCODINGS           () { ( qw(ascii iso-8859-1 UTF-8 guess) ) }
sub EXCEPTION_CLASS     () { __PACKAGE__->Exception_Class }
sub LOG_LEVELS          () { ( qw(alert debug error fatal info warn) ) }
sub UNTAINT_CMDLINE     () { qr{ \A ([^\$%;|&><\*]+) \z }mx }
sub UNTAINT_IDENTIFIER  () { qr{ \A ([a-zA-Z0-9_]+)  \z }mx }
sub UNTAINT_PATH        () { qr{ \A ([^\$%;|&><\*]+) \z }mx }
sub UUID_PATH           () { [ NUL, qw(proc sys kernel random uuid) ] }

__PACKAGE__->meta->make_immutable;

no MooseX::ClassAttribute;
no Moose;

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

String I<ARRAY>

=head2 ASSERT

Return a coderef which is imported by L<Class::Usul::Functions> into
the callers namespace as the C<assert> function. By default this will
be the empty subroutine, sub {}. Change this by setting the I<Assert>
class attribute

=head2 BRK

Separate leader (: ) from message

=head2 CODE

String I<CODE>

=head2 CONFIG_EXTN

The default configuration file extension, I<.json>. Change this by
setting the I<Config_Extn> class attribute

=head2 DEFAULT_DIR

An arrayref which if passed to L<catfile|File::Spec/catdir> is the directory
which will contain the applications installation information

=head2 DEFAULT_ENCODING

String I<UTF-8>

=head2 DEFAULT_L10N_DOMAIN

String I<default>. The name of the default message catalog

=head2 DIGEST_ALGORITHMS

List of algorithms to try as args to L<Digest>

=head2 ENCODINGS

List of supported IO encodings

=head2 EVIL

The L<Config> osname of the other operating system

=head2 EXCEPTION_CLASS

The name of the class used to throw exceptions. Defaults to
L<File::DataClass::Exception> but can be changed by setting the
I<Exception_Class> class attribute

=head2 EXTNS

List of possible file suffixes used on Perl scripts

=head2 FAILED

Non zero exit code indicating program failure

=head2 FALSE

Digit I<0>

=head2 HASH

String I<HASH>

=head2 LANG

Default language code, I<en>

=head2 LBRACE

The left brace character, I<{>

=head2 LOCALIZE

The character sequence that introduces a localization substitution
parameter, I<[_>

=head2 LOG_LEVELS

List of methods the log object is expected to support

=head2 NO

The letter I<n>

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

=head2 SEP

Slash I</> character

=head2 SPC

Space character

=head2 TRUE

Digit I<1>

=head2 UNTAINT_CMDLINE

Regular expression used to untaint command line strings

=head2 UNTAINT_IDENTIFIER

Regular expression used to untaint identifier strings

=head2 UNTAINT_PATH

Regular expression used to untaint path strings

=head2 UUID_PATH

An arrayref which if passed to L<catfile|File::Spec/catdir> is the path
which will return a unique identifier if opened and read

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

=item L<File::DataClass::Constants>

=item L<File::DataClass::Exception>

=item L<Moose>

=item L<MooseX::ClassAttribute>

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
