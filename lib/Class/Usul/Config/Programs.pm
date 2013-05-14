# @(#)$Ident: Programs.pm 2013-04-29 19:28 pjf ;

package Class::Usul::Config::Programs;

use version; our $VERSION = qv( sprintf '0.20.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use File::Basename               qw(basename);
use File::DataClass::Constraints qw(Path);
use File::HomeDir;

extends qw(Class::Usul::Config);

has 'doc_title'    => is => 'ro',   isa => NonEmptySimpleStr,
   default         => 'User Contributed Documentation';

has 'man_page_cmd' => is => 'ro',   isa => ArrayRef,
   default         => sub { [ qw(nroff -man) ] };

has 'mode'         => is => 'ro',   isa => PositiveInt, default => MODE;

has 'my_home'      => is => 'lazy', isa => Path, coerce => TRUE,
   default         => sub { File::HomeDir->my_home };

has 'owner'        => is => 'lazy', isa => NonEmptySimpleStr;

has 'script'       => is => 'lazy', isa => NonEmptySimpleStr;

# Private methods

sub _build_owner {
   return $_[ 0 ]->_inflate_symbol( $_[ 1 ], q(prefix) ) || q(root);
}

sub _build_script {
   return basename( $_[ 0 ]->_inflate_path( $_[ 1 ], qw(pathname) ) );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

Class::Usul::Config::Programs - Additional configuration attributes for CLI programs

=head1 Version

This documents version v0.20.$Rev: 1 $

=head1 Synopsis

   package Class::Usul::Programs;

   use Class::Usul::Moose;

   extends q(Class::Usul);

   has '+config_class' => default => q(Class::Usul::Config::Programs);

=head1 Description

Additional configuration attributes for CLI programs

=head1 Configuration and Environment

Defines the following list of attributes

=over 3

=item C<doc_title>

String defaults to 'User Contributed Documentation'. Used in the Unix man
pages

=item C<man_page_cmd>

Array ref containing the command and options to produce a man page. Defaults
to C<man -nroff>

=item C<mode>

Integer defaults to the constant C<MODE>. The default file creation mask

=item C<owner>

String. Name of the application file owner

=item C<script>

String. The basename of the C<pathname> attribute

=back

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Config>

=item L<Class::Usul::Moose>

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
