package Class::Usul::TraitFor::OutputLogging;

use namespace::autoclean;

use Class::Usul::Constants qw( BRK FAILED FALSE NUL TRUE WIDTH );
use Class::Usul::Functions qw( abs_path emit emit_to emit_err );
use Text::Autoformat;
use Moo::Role;

requires qw( config loc log quiet );

# Public methods
sub add_leader {
   my ($self, $text, $args) = @_; $text or return NUL; $args //= {};

   my $leader = $args->{no_lead} ? NUL : (ucfirst $self->config->name).BRK;

   if ($args->{fill}) {
      my $width = $args->{width} // WIDTH;

      $text = autoformat $text, { right => $width - 1 - length $leader };
   }

   return join "\n", map { (m{ \A $leader }mx ? NUL : $leader).$_ }
                     split  m{ \n }mx, $text;
}

sub error {
   my ($self, $text, $args) = @_; $args //= {};

   $text = $self->loc( $text // '[no message]', $args->{args} // [] );

   $self->log->error( $_ ) for (split m{ \n }mx, "${text}");

   emit_to *STDERR, $self->add_leader( $text, $args )."\n";
   return TRUE;
}

sub fatal {
   my ($self, $text, $args) = @_; my (undef, $file, $line) = caller 0;

   my $posn = ' at '.abs_path( $file )." line ${line}"; $args //= {};

   $text = $self->loc( $text // '[no message]', $args->{args} // [] );

   $self->log->alert( $_ ) for (split m{ \n }mx, $text.$posn);

   emit_to *STDERR, $self->add_leader( $text, $args )."${posn}\n";
   exit FAILED;
}

sub info {
   my ($self, $text, $args) = @_; $args //= {};

   my $opts = { params => $args->{args} // [], quote_bind_values => FALSE, };

   $text = $self->loc( $text // '[no message]', $opts );

   $self->log->info( $_ ) for (split m{ [\n] }mx, $text);

   $self->quiet or $args->{quiet} or emit $self->add_leader( $text, $args );
   return TRUE;
}

sub output {
   my ($self, $text, $args) = @_; $args //= {};

   my $opts = { params => $args->{args} // [], quote_bind_values => FALSE, };

   $text = $self->loc( $text // '[no message]', $opts );

   my $code = sub {
      $args->{to} && $args->{to} eq 'err' ? emit_err( @_ ) : emit( @_ );
   };

   $code->() if $args->{cl};
   $code->( $self->add_leader( $text, $args ) );
   $code->() if $args->{nl};
   return TRUE;
}

sub warning {
   my ($self, $text, $args) = @_; $args //= {};

   $text = $self->loc( $text // '[no message]', $args->{args} // [] );

   $self->log->warn( $_ ) for (split m{ \n }mx, $text);

   $self->quiet or $args->{quiet} or emit $self->add_leader( $text, $args );
   return TRUE;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Class::Usul::TraitFor::OutputLogging - Localised logging and command line output methods

=head1 Synopsis

   use Moo;

   extends 'Class::Usul';
   with    'Class::Usul::TraitFor::OutputLogging';

=head1 Description

=head1 Configuration and Environment

Defines no attributes. Requires the following;

=over 3

=item C<config>

=item C<loc>

=item C<log>

=item C<quiet>

=back

=head1 Subroutines/Methods

=head2 add_leader

   $leader = $self->add_leader( $text, $args );

Prepend C<< $self->config->name >> to each line of C<$text>. If
C<< $args->{no_lead} >> exists then do nothing. Return C<$text> with
leader prepended

=head2 error

   $self->error( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Logs the result at the error level, then adds the
program leader and prints the result to I<STDERR>

=head2 fatal

   $self->fatal( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Logs the result at the alert level, then adds the
program leader and prints the result to I<STDERR>. Exits with a return
code of one

=head2 info

   $self->info( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Logs the result at the info level, then adds the
program leader and prints the result to I<STDOUT>

=head2 output

   $self->output( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Adds the program leader and prints the result to
I<STDOUT>

=head2 warning

   $self->warning( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Logs the result at the warning level, then adds the
program leader and prints the result to I<STDOUT>

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Text::Autoformat>

=item L<Moo::Role>

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
# vim: expandtab shiftwidth=3:
