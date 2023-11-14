package Class::Usul::Options;

use Moo;

extends 'Class::Usul::Cmd::Options';

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Class::Usul::Options - Command line processing

=head1 Synopsis

   use Class::Usul::Types qw( Str );
   use Moo;
   use Class::Usul::Options;

   option 'my_attr' => is => 'ro', isa => 'Str',
      documentation => 'This appears in the option usage output',
             format => 's', short => 'a';

   # OR
   # Causes Getopt::Long:Descriptive::Usage to produce it's new default output

   use Class::Usul::Options 'usage_conf' => {
       highlight => 'none', option_type => 'verbose', tabstop => 8 };

   # OR
   # Causes Getopt::Long:Descriptive::Usage to produce it's old default output

   use Class::Usul::Options 'usage_conf' => {
       highlight => 'none', option_type => 'none', tabstop => 8 };

=head1 Description

This is an extended clone of L<MooX::Options> but is closer to
L<MooseX::Getopt::Dashes>

=head1 Configuration and Environment

The C<option> function accepts the following attributes in addition to those
already supported by C<has>

=over 3

=item C<autosplit>

If set split the option value using this string. Automatically creates a list
of values

=item C<config>

A hash reference passed as the third element in the
list of tuples which forms the second argument to the
L<describe options|Getopt::Long::Descriptive/describe_options> function

For example;

   option 'my_attr' => is => 'ro', isa => 'Str', config => { hidden => 1 },
      documentation => 'This appears in the option usage output',
             format => 's', short => 'a';

would prevent the option from appearing in the usage text

=item C<doc>

Alias for C<documentation>. Used to describe the attribute in the usage output

=item C<format>

Format of the parameters, same as L<Getopt::Long::Descriptive>

    i : integer

    i@: array of integer

    s : string

    s@: array of string

    s%: hash of string

    f : float value

By default, it's a boolean value.

=item C<json>

Boolean which if true means that the argument to the option is in JSON format
and will be decoded as such

=item C<negateable>

Applies only to boolean types. Means you can use C<--nooption-name> to
explicitly indicate false

=item C<order>

Specifies the order in which usage options appear. Attributes with no C<order>
value are alpha sorted

=item C<repeatable>

Boolean which if true means that the option can appear multiple times on the
command line

=item C<short>

A single character that can be used as a short option, e.g. C<-s> instead
of the longer C<--long-option>

=back

Defines no attributes

=head1 Subroutines/Methods

=over 3

=item C<default_options_config>

Returns a list of keys and values. These are the defaults for the configuration
options listed in L</import>

=item C<import>

Injects the C<option> function into the caller

Accepts the following configuration options;

=over 3

=item C<getopt_conf>

An array reference of options passed to L<Getopt::Long::Configure>, defaults to
an empty list

=item C<prefer_commandline>

A boolean which defaults to true. Prefer the command line values

=item C<protect_argv>

A boolean which defaults to true. Localises the C<@ARGV> variable before any
processing takes place. Means that C<@ARGV> will contain all of the passed
command line arguments

=item C<show_defaults>

A boolean which defaults to false. If true the default values are added to
use options usage text output

=item C<skip_options>

An array reference which defaults to an empty list. List of options to
ignore when processing the attributes passed to the C<option> subroutine

=item C<usage_conf>

By default an empty hash reference. Attributes can be any of;

=over 3

=item C<highlight>

Defaults to C<bold> which causes the option argument types to be displayed
in a bold font. Set to C<none> to turn off highlighting

=item C<option_type>

One of; C<none>, C<short>, or C<verbose>. Determines the amount of option
type information displayed by the L<option_text|Class::Usul::Usage/option_text>
method. Defaults to C<short>

=item C<tabstop>

Defaults to 3. The number of spaces to expand the leading tab in the usage
string

=item C<width>

The total line width available for displaying usage text, defaults to 78

=back

=item C<usage_opt>

The usage option string passed as the first argument to the
L<describe options|Getopt::Long::Descriptive/describe_options> function.
Defaulted in L</default_options_config> to C<Usage: %c %o [method]>

=back

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd::Options>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Usul.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2023 Peter Flanigan. All rights reserved

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
