package Class::Usul::Config::Programs;

use namespace::autoclean;

use Moo;
use Class::Usul::Constants qw( MODE TRUE );
use Class::Usul::Types     qw( ArrayRef Bool NonEmptySimpleStr
                               NonZeroPositiveInt PositiveInt );
use File::Basename         qw( basename );
use File::DataClass::Types qw( Path OctalNum );
use File::HomeDir;

extends q(Class::Usul::Config);

# Construction
my $_build_owner = sub {
   return $_[ 0 ]->inflate_symbol( $_[ 1 ], 'prefix' ) || 'root';
};

my $_build_script = sub {
   return basename( $_[ 0 ]->inflate_path( $_[ 1 ], 'pathname' ) );
};

# Public attributes
has 'doc_title'    => is => 'ro',   isa => NonEmptySimpleStr,
   default         => 'User Contributed Documentation';

has 'man_page_cmd' => is => 'ro',   isa => ArrayRef,
   builder         => sub { [ 'nroff', '-man' ] };

has 'mode'         => is => 'ro',   isa => OctalNum, coerce => TRUE,
   default         => MODE;

has 'my_home'      => is => 'lazy', isa => Path, coerce => TRUE,
   builder         => sub { File::HomeDir->my_home };

has 'owner'        => is => 'lazy', isa => NonEmptySimpleStr,
   builder         => $_build_owner;

has 'pwidth'       => is => 'ro',   isa => NonZeroPositiveInt, default => 60;

has 'script'       => is => 'lazy', isa => NonEmptySimpleStr,
   builder         => $_build_script;

1;

__END__

=pod

=head1 Name

Class::Usul::Config::Programs - Additional configuration attributes for CLI programs

=head1 Synopsis

   package Class::Usul::Programs;

   use Moo;

   extends q(Class::Usul);

   has '+config_class' => default => q(Class::Usul::Config::Programs);

=head1 Description

Additional configuration attributes for CLI programs

=head1 Configuration and Environment

Defines the following list of attributes

=over 3

=item C<cache_ttys>

Boolean defaults to true. Passed to the L<Proc::ProcessTable> constructor

=item C<doc_title>

String defaults to 'User Contributed Documentation'. Used in the Unix man
pages

=item C<man_page_cmd>

Array ref containing the command and options to produce a man page. Defaults
to C<man -nroff>

=item C<mode>

Integer defaults to the constant C<MODE>. The default file creation mask

=item C<my_home>

A directory object reference which defaults to the users home

=item C<owner>

String. Name of the application file owner

=item C<pwidth>

Integer. Number of characters used to justify command line prompts

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

=item L<Moo>

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

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
