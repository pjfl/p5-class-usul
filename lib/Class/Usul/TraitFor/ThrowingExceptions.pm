# @(#)Ident: ThrowingExceptions.pm 2013-04-29 03:41 pjf ;

package Class::Usul::TraitFor::ThrowingExceptions;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose::Role;
use English qw(-no_match_vars);

# Public methods
sub caught {
   my ($self, @args) = @_; my $attr = __get_attr( @args );

   my $error = $attr->{error} ||= $EVAL_ERROR; $error or return;

   return __is_one_of_us( $error ) ? $error : $self->new( $attr );
}

sub throw {
   my ($self, @args) = @_;

   die __is_one_of_us( $args[ 0 ] ) ? $args[ 0 ] : $self->new( @args );
}

sub throw_on_error {
   my ($self, @args) = @_; my $e;

   $e = $self->caught( @args ) and $self->throw( $e );

   return;
}

# Private functions
sub __get_attr {
   return ($_[ 0 ] && ref $_[ 0 ] eq q(HASH)) ? { %{ $_[ 0 ] } }
        : (defined $_[ 1 ])                   ? { @_ }
                                              : { error => $_[ 0 ] };
}

sub __is_one_of_us {
   return $_[ 0 ] && blessed $_[ 0 ] && $_[ 0 ]->isa( __PACKAGE__ );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Class::Usul::TraitFor::ThrowingExceptions - One-line description of the modules purpose

=head1 Synopsis

   use Class::Usul::TraitFor::ThrowingExceptions;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev$ of L<Class::Usul::TraitFor::ThrowingExceptions>

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

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
