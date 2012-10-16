# @(#)$Id$

package Class::Usul;

use strict;
use version; our $VERSION = qv( sprintf '0.8.%d', q$Rev$ =~ /\d+/gmx );

use 5.010;
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions qw(data_dumper merge_attributes);
use Class::Usul::Config;
use Class::Usul::L10N;
use Class::Usul::Log;
use IPC::SRLock;

coerce ConfigType, from HashRef, via { Class::Usul::Config->new( $_ ) };

has '_config'    => is => 'ro',   isa => ConfigType, coerce => TRUE,
   handles       => [ qw(prefix salt) ], init_arg => 'config',
   reader        => 'config', required => TRUE;

has 'debug',     => is => 'rw',   isa => Bool, default => FALSE,
   documentation => 'Turn debugging on. Prompts if interactive',
   trigger       => TRUE;

has 'encoding'   => is => 'lazy', isa => EncodingType, coerce => TRUE,
   documentation => 'Decode/encode input/output using this encoding',
   default       => sub { $_[ 0 ]->config->encoding };

has '_l10n'      => is => 'lazy', isa => L10NType,
   default       => sub { Class::Usul::L10N->new( builder => $_[ 0 ] ) },
   handles       => [ qw(localize) ], init_arg => 'l10n', reader => 'l10n';

has '_lock'      => is => 'lazy', isa => LockType,
   init_arg      => 'lock', reader => 'lock';

has '_log'       => is => 'lazy', isa => LogType,
   default       => sub { Class::Usul::Log->new( builder => $_[ 0 ] ) },
   init_arg      => 'log',  reader => 'log';

sub dumper {
   my $self = shift; return data_dumper( @_ ); # Damm handy for development
}

# Private methods

sub _build__lock { # There is only one lock object. Instantiate on first use
   my $self = shift; state $cache; $cache and return $cache;

   my $config = $self->config; my $attr = { %{ $config->lock_attributes } };

   merge_attributes $attr, $self,   {}, [ qw(debug log) ];
   merge_attributes $attr, $config, {}, [ qw(tempdir) ];

   return $cache = IPC::SRLock->new( $attr );
}

sub _trigger_debug {
   my ($self, $debug) = @_;

   $self->l10n->debug( $debug ); $self->lock->debug( $debug );

   return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

Class::Usul - A base class other packages

=head1 Version

Describes Class::Usul version 0.8.$Revision$

=head1 Synopsis

   use Class::Usul::Moose;

   extends qw(Class::Usul);

=head1 Description

These modules provide a set of base classes for Perl packages and applications

=head1 Configuration and Environment

   $self = Class::Usul->new( $attr );

The C<$attr> argument is a hash ref containing the object attributes.

=over 3

=item config

The C<config> attribute should be a hash ref that may define key/value pairs
that provide filesystem paths for the temporary directory etc.

=item debug

Defaults to false

=item encoding

Decode input and encode output. Defaults to C<UTF-8>

=back

Defined the application context log. Defaults to a L<Class::Null> object

=head1 Subroutines/Methods

=head2 dumper

   $self->dumper( $some_var );

Use L<Data::Printer> to dump arguments for development purposes

=head2 _build__lock

Defines the lock object. This instantiates on first use

An L<IPC::SRLock> object which is used to single thread the
application where required. This is a singleton object.  Provides
defaults for and returns a new L<IPC::SRLock> object. The keys of the
C<< $self->config->lock_attributes >> hash are:

=over 3

=item debug

Debug status. Defaults to C<< $self->debug >>

=item log

Logging object. Defaults to C<< $self->log >>

=item tempdir

Directory used to store the lock file and lock table if the C<fcntl> backend
is used. Defaults to C<< $self->config->tempdir >>

=back

=head1 Diagnostics

Setting the I<debug> attribute to true causes messages to be logged at the
debug level

=head1 Dependencies

=over 3

=item L<Class::Usul::Constants>

=item L<Class::Usul::Functions>

=item L<Class::Usul::L10N>

=item L<Class::Usul::Log>

=item L<Class::Usul::Moose>

=item L<IPC::SRLock>

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
