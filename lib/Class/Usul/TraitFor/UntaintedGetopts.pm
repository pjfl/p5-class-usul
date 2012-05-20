# @(#)$Id$

package Class::Usul::TraitFor::UntaintedGetopts;

use strict;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose::Role;
use Class::Usul::Functions qw(untaint_cmdline);

with qw(MooseX::Getopt::Dashes);

around _parse_argv => sub {
   my ($next, $self, @args) = @_;

   @ARGV = map { untaint_cmdline $_ } @ARGV;

   return $self->$next( @args );
};

no Moose::Role;

1;

__END__

=pod

=head1 Name

Class::Usul::TraitFor::UntaintedGetopts - Untaints @ARGV before Getopts processes it

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use Class::Usul::Moose;

   with 'Class::Usul::TraitFor::UntaintedGetopts';

=head1 Description

Untaints @ARGV before Getopts processes it

=head1 Subroutines/Methods

=head2 _parse_argv

Modifies this method in L<MooseX::Getopt>. Untaints the values of the
I<@ARGV> array before the are parsed by L<MooseX::Getopt>

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moose::Role>

=item L<MooseX::Getopt::Dashes>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

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