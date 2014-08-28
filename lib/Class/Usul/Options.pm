package Class::Usul::Options;

use strict;
use warnings;

use Class::Usul::Constants qw( TRUE );
use Class::Usul::Functions qw( throw );
use Sub::Install           qw( install_sub );

my @OPTIONS_ATTRIBUTES
   = qw( autosplit doc format json negateable order repeatable short );

# Public methods
sub import {
   my ($class, @args) = @_; my $target = caller;

   my $options_config = { protect_argv       => TRUE,
                          flavour            => [],
                          skip_options       => [],
                          prefer_commandline => TRUE,
                          @args, };

   for my $want (grep { not $target->can( $_ ) } qw( around has with )) {
      throw error => 'Method [_1] not found in class [_2]',
             args => [ $want, $target ];
   }

   my $around = $target->can( 'around' );
   my $has    = $target->can( 'has'    );
   my $with   = $target->can( 'with'   );

   my @target_isa; { no strict 'refs'; @target_isa = @{ "${target}::ISA" } };

   if (@target_isa) {
      # Don't add this to a role. The ISA of a role is always empty!
      install_sub { as => '_options_config', into => $target, code => sub {
         return shift->maybe::next::method( @_ );
      }, };

      install_sub { as => '_options_data', into => $target, code => sub {
         return shift->maybe::next::method( @_ );
      }, };

      $around->( '_options_config' => sub {
         my ($orig, $self, @args) = @_;

         return $self->$orig( @args ), %{ $options_config };
      } );
   }

   my $options_data    = {};
   my $apply_modifiers = sub {
      $target->can( 'new_with_options' ) and return;

      $with->( 'Class::Usul::TraitFor::UntaintedGetopts' );

      $around->( '_options_data' => sub {
         my ($orig, $self, @args) = @_;

         return $self->$orig( @args ), %{ $options_data };
      } );
   };
   my $option = sub {
      my ($name, %attributes) = @_;

      my @banish_keywords = qw( extra_argv new_with_options next_argv option
                                _options_data _options_config options_usage
                                _parse_options unshift_argv );

      for my $ban (grep { $_ eq $name } @banish_keywords) {
         throw error => 'Method [_1] used by class [_2] as an attribute',
                args =>[ $ban, $target ];
      }

      $has->( $name => _filter_attributes( %attributes ) );

      $options_data->{ $name }
         = { _validate_and_filter_options( %attributes ) };

      $apply_modifiers->(); # TODO: I think this can go
      return;
   };
   my $info; $info = $Role::Tiny::INFO{ $target }
      and $info->{not_methods}{ $option } = $option;

   install_sub { as => 'option', into => $target, code => $option, };

   $apply_modifiers->();
   return;
}

# Private methods
sub _filter_attributes {
   my %attributes = @_; my %filter_key = map { $_ => 1 } @OPTIONS_ATTRIBUTES;

   return map { ( $_ => $attributes{ $_ } ) }
         grep { not exists $filter_key{ $_ } } keys %attributes;
}

sub _validate_and_filter_options {
   my (%options) = @_;

   defined $options{doc  } or $options{doc  } = $options{documentation};
   defined $options{order} or $options{order} = 0;

   if ($options{json}) {
      delete $options{repeatable}; delete $options{autosplit};
      delete $options{negateable}; $options{format} = 's';
   }

   my %cmdline_options = map { ( $_ => $options{ $_ } ) }
      grep { exists $options{ $_ } } @OPTIONS_ATTRIBUTES, 'required';

   $cmdline_options{autosplit} and $cmdline_options{repeatable} = TRUE;
   $cmdline_options{repeatable}
      and defined $cmdline_options{format}
      and (substr $cmdline_options{format}, -1) ne '@'
      and $cmdline_options{format} .= '@';

   $cmdline_options{negateable} and defined $cmdline_options{format} and
      throw 'Negateable parameters are not usable with a non boolean values';

   return %cmdline_options;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Class::Usul::Options - Command line processing

=head1 Synopsis

   use Moo;
   use Class::Usul::Options;

=head1 Description

This is a clone of L<MooX::Options> but is closer to L<MooseX::Getopt::Dashes>

=head1 Configuration and Environment

Format of the parameters, same as L<Getopt::Long::Descriptive>

    i : integer

    i@: array of integer

    s : string

    s@: array of string

    s%: hash of string

    f : float value

By default, it's a boolean value.

Defines no attributes

=head1 Subroutines/Methods

=head2 import

Inject the C<option> method into the caller

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Sub::Install>

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

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
