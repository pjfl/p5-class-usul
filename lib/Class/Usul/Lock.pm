# @(#)Ident: Lock.pm 2013-08-04 16:50 pjf ;

package Class::Usul::Lock;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.29.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( emit );
use Class::Usul::Time;
use Class::Usul::Types      qw( Int Str );
use Moo;
use MooX::Options;

extends q(Class::Usul::Programs);

option 'lock_key'     => is => 'ro', format => 's',
   documentation      => 'Key used to set/reset a lock',
   short              => q(k);

option 'lock_pid'     => is => 'ro', format => 'i',
   documentation      => 'Process id associated with a lock. Defaults to $$',
   short              => q(p);

option 'lock_timeout' => is => 'ro', format => 'i',
   documentation      => 'Timeout in secounds before a lock is declared stale',
   short              => q(t);

sub list : method {
   my $self = shift; my $line;

   for my $ref (@{ $self->lock->list || [] }) {
      $line  = $ref->{key}.q(,).$ref->{pid}.q(,);
      $line .= time2str( '%Y-%m-%d %H:%M:%S', $ref->{stime} ).q(,);
      $line .= $ref->{timeout};
      emit $line;
   }

   return OK;
}

sub reset : method {
   my $self = shift; $self->lock->reset( k => $self->lock_key ); return OK;
}

sub set : method {
   my $self = shift;

   $self->lock->set( k => $self->lock_key,
                     p => $self->lock_pid,
                     t => $self->lock_timeout );
   return OK;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Class::Usul::Lock - Command line access to the L<IPC::SRLock> methods

=head1 Version

This documents version v0.29.$Rev: 1 $ of L<Class::Usul::Lock>

=head1 Synopsis

   use Class::Usul::Lock;

   my $app = Class::Usul::Lock->new_with_options( appclass => 'YourApp' );

   $app->quiet( 1 );

   exit $app->run;

=head1 Description

Command line access to the L<IPC::SRLock> methods

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item lock_key

String which is the key used to set/reset a lock. Set from the command line
with the C<k> switch

=item lock_pid

Integer which is the process id associated with a lock. Defaults to
C<$PID>. Set from the command line with the C<p> switch

=item lock_timeout

Integer which is the timeout in seconds before a lock is declared
stale.  Defaults to five minutes. Set from the command line with the
C<t> switch

=back

=head1 Subroutines/Methods

=head2 list

Lists the locks in the lock table

=head2 reset

Resets the lock keyed by the C<lock_key> attribute

=head2 set

Set the lock keyed by the I<lock_key> attribute. Optionally use the
C<lock_pid> and C<lock_timeout> attributes

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Programs>

=item L<Class::Usul::Time>

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
