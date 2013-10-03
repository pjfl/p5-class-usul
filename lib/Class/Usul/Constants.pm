# @(#)$Ident: Constants.pm 2013-09-27 11:52 pjf ;

package Class::Usul::Constants;

use 5.010001;
use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.30.%d', q$Rev: 1 $ =~ /\d+/gmx );
use parent                  qw( Exporter::Tiny );

use Class::Usul::Exception;

our @EXPORT = qw( ARRAY ASSERT BRK CODE CONFIG_EXTN DEFAULT_DIR
                  DEFAULT_ENCODING DEFAULT_L10N_DOMAIN
                  DIGEST_ALGORITHMS ENCODINGS EVIL EXCEPTION_CLASS
                  EXTNS FAILED FALSE HASH LANG LBRACE LOCALIZE
                  LOG_LEVELS MODE NO NUL OK PHASE PREFIX QUIT SEP
                  SPC TRUE UNDEFINED_RV UNTAINT_CMDLINE
                  UNTAINT_IDENTIFIER UNTAINT_PATH USUL_CONFIG_KEY
                  UUID_PATH WIDTH YES );

my $Assert          = sub {};
my $Config_Extn     = '.json';
my $Config_Key      = 'Plugin::Usul';
my $Exception_Class = 'Class::Usul::Exception';

sub ARRAY    () { q(ARRAY)           }
sub BRK      () { q(: )              }
sub CODE     () { q(CODE)            }
sub EVIL     () { q(mswin32)         }
sub EXTNS    () { ( qw(.pl .pm .t) ) }
sub FAILED   () { 1                  }
sub FALSE    () { 0                  }
sub HASH     () { q(HASH)            }
sub LANG     () { q(en)              }
sub LBRACE   () { q({)               }
sub LOCALIZE () { q([_)              }
sub MODE     () { oct q(027)         }
sub NO       () { q(n)               }
sub NUL      () { q()                }
sub OK       () { 0                  }
sub PHASE    () { 2                  }
sub PREFIX   () { [ q(), q(opt) ]    }
sub QUIT     () { q(q)               }
sub SEP      () { q(/)               }
sub SPC      () { q( )               }
sub TRUE     () { 1                  }
sub WIDTH    () { 80                 }
sub YES      () { q(y)               }

sub ASSERT              () { __PACKAGE__->Assert }
sub CONFIG_EXTN         () { __PACKAGE__->Config_Extn }
sub DEFAULT_DIR         () { [ q(), qw(etc default) ] }
sub DEFAULT_ENCODING    () { q(UTF-8) }
sub DEFAULT_L10N_DOMAIN () { q(default) }
sub DIGEST_ALGORITHMS   () { ( qw(SHA-512 SHA-256 SHA-1 MD5) ) }
sub ENCODINGS           () { ( qw(ascii iso-8859-1 UTF-8 guess) ) }
sub EXCEPTION_CLASS     () { __PACKAGE__->Exception_Class }
sub LOG_LEVELS          () { ( qw(alert debug error fatal info warn) ) }
sub UNDEFINED_RV        () { -1 }
sub UNTAINT_CMDLINE     () { qr{ \A ([^\$;|&><]+)    \z }mx }
sub UNTAINT_IDENTIFIER  () { qr{ \A ([a-zA-Z0-9_]+)  \z }mx }
sub UNTAINT_PATH        () { qr{ \A ([^\$%;|&><\*]+) \z }mx }
sub USUL_CONFIG_KEY     () { __PACKAGE__->Config_Key }
sub UUID_PATH           () { [ q(), qw(proc sys kernel random uuid) ] }

sub Assert {
   my ($self, $subr) = @_; defined $subr or return $Assert;

   ref $subr eq 'CODE' or $self->Exception_Class->throw
      ( 'Assert subroutine ${subr} is not a code reference' );

   return $Assert = $subr;
}

sub Config_Extn {
   my ($self, $extn) = @_; defined $extn or return $Config_Extn;

   (length $extn < 255 and $extn !~ m{ \n }mx) or $self->Exception_Class->throw
      ( 'Config extension ${extn} is not a simple string' );

   return $Config_Extn = $extn;
}

sub Config_Key {
   my ($self, $key) = @_; defined $key or return $Config_Key;

   (length $key < 255 and $key !~ m{ \n }mx) or $self->Exception_Class->throw
      ( 'Config key ${key} is not a simple string' );

   return $Config_Key = $key;
}

sub Exception_Class {
   my ($self, $class) = @_; defined $class or return $Exception_Class;

   $class->can( q(throw) ) or Class::Usul::Exception->throw
      ( "Exception class ${class} is not loaded or has no throw method" );

   return $Exception_Class = $class;
}

1;

__END__

=pod

=head1 Name

Class::Usul::Constants - Definitions of constant values

=head1 Version

This documents version v0.30.$Rev: 1 $

=head1 Synopsis

   use Class::Usul::Constants;

   my $bool = TRUE; my $slash = SEP;

=head1 Description

Exports a list of subroutines each of which returns a constants value

=head1 Configuration and Environment

Defines the following class attributes;

=over 3

=item C<Assert>

=item C<Config_Extn>

=item C<Config_Key>

=item C<Exception_Class>

=back

=head1 Subroutines/Methods

=head2 ARRAY

String C<ARRAY>

=head2 ASSERT

Return a coderef which is imported by L<Class::Usul::Functions> into
the callers namespace as the C<assert> function. By default this will
be the empty subroutine, C<sub {}>. Change this by setting the C<Assert>
class attribute

=head2 BRK

Separate leader from message,  (: )

=head2 CODE

String C<CODE>

=head2 CONFIG_EXTN

The default configuration file extension, F<.json>. Change this by
setting the C<Config_Extn> class attribute

=head2 DEFAULT_DIR

An arrayref which if passed to L<catfile|File::Spec/catdir> is the directory
which will contain the applications installation information

=head2 DEFAULT_ENCODING

String C<UTF-8>

=head2 DEFAULT_L10N_DOMAIN

String C<default>. The name of the default message catalog

=head2 DIGEST_ALGORITHMS

List of algorithms to try as args to L<Digest>

=head2 ENCODINGS

List of supported IO encodings

=head2 EVIL

The L<Config> operating system name of the one whose name cannot be spoken
out loud

=head2 EXCEPTION_CLASS

The name of the class used to throw exceptions. Defaults to
L<Class::Usul::Exception> but can be changed by setting the
C<Exception_Class> class attribute

=head2 EXTNS

List of possible file suffixes used on Perl scripts

=head2 FAILED

Non zero exit code indicating program failure

=head2 FALSE

Digit C<0>

=head2 HASH

String C<HASH>

=head2 LANG

Default language code, C<en>

=head2 LBRACE

The left brace character, C<{>

=head2 LOCALIZE

The character sequence that introduces a localization substitution
parameter, C<[_>

=head2 LOG_LEVELS

List of methods the log object is expected to support

=head2 MODE

Default file creation mask

=head2 NO

The letter C<n>

=head2 NUL

Empty string

=head2 OK

Returns good program exit code, zero

=head2 PHASE

The default phase number used to select installation specific config

=head2 PREFIX

Array ref representing the default parent path for a normal install

=head2 QUIT

The character q

=head2 SEP

Slash C</> character

=head2 SPC

Space character

=head2 TRUE

Digit C<1>

=head2 UNDEFINED_RV

Digit C<-1>. Indicates that a method wrapped in a try/catch block failed
to return a defined value

=head2 UNTAINT_CMDLINE

Regular expression used to untaint command line strings

=head2 UNTAINT_IDENTIFIER

Regular expression used to untaint identifier strings

=head2 UNTAINT_PATH

Regular expression used to untaint path strings

=head2 USUL_CONFIG_KEY

Default configuration hash key, C<Plugin::Usul>. Change this by setting
the C<Config_Key> class attribute

=head2 UUID_PATH

An arrayref which if passed to L<catfile|File::Spec/catdir> is the path
which will return a unique identifier if opened and read

=head2 WIDTH

Default terminal screen width in characters

=head2 YES

The character y

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Exporter>

=item L<Class::Usul::Exception>

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
