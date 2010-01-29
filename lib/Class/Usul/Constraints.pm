# @(#)$Id$

package Class::Usul::Constraints;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev$ =~ /\d+/gmx );

use Class::Null;
use Class::Usul::Constants;
use Moose::Role;
use Moose::Util::TypeConstraints;

subtype 'C_U_Log' => as 'Object' =>
   where   { $_->isa( q(Class::Null) ) or __has_log_level_methods( $_ ) } =>
   message { 'Object '.(blessed $_ || $_).' is missing a log level method' };

enum 'C_U_Encoding' => ENCODINGS;
enum 'C_U_Digest_Algorithm' => DIGEST_ALGORITHMS;

sub __has_log_level_methods {
   my $obj = shift;

   $obj->can( $_ ) or return FALSE for (LOG_LEVELS);

   return TRUE;
}

no Moose::Util::TypeConstraints;
no Moose::Role;

1;

__END__

=pod

=head1 Name

Class::Usul::Constraints -  Role defining package constraints

=head1 Version

This document describes Class::Usul::Constraints version 0.2.$Revision$

=head1 Synopsis

   use Moose;

   extends qw(Class::Usul);

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

Setting the I<debug> attribute to true causes messages to be logged at the
debug level

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

