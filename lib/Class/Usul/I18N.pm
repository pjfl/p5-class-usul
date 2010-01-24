# @(#)$Id$

package Class::Usul::I18N;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Constants;

*loc = \&localize;

sub localize {
   my ($self, $messages, $key, @rest) = @_; $messages ||= {};

   $key or return; $key = NUL.$key; chomp $key;

   # Lookup the message using the supplied key
   my $msg  = $messages->{ $key };
   my $text = ($msg && ref $msg eq HASH ? $msg->{text} : $msg) || $key;

   # Expand positional parameters of the form [_<n>]
   0 > index $text, LOCALIZE and return $text;

   my @args = $rest[0] && ref $rest[0] eq ARRAY ? @{ $rest[0] } : @rest;

   push @args, map { NUL } 0 .. 10;
   $text =~ s{ \[ _ (\d+) \] }{$args[ $1 - 1 ]}gmx;
   return $text;
}

1;

__END__

=pod

=head1 Name

Class::Usul::I18N - Localize text strings

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use Class::Usul::I18N;

=head1 Description

Localize text strings

=head1 Subroutines/Methods

=head2 loc

=head2 localize

   $local_text = $self->localize( $messages, $key, @args );

Localizes the message. The message catalog (hash) is in
C<< $messages >>. Expands positional parameters of
the form C<< [_<n>] >>. Returns the C<$key> if the message is not
in the catalog

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Constants>

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

