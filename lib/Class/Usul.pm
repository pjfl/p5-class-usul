# @(#)$Id$

package Class::Usul;

use strict;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use 5.010;
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Constraints     qw(ConfigType EncodingType LogType);
use Class::Usul::Functions       qw(data_dumper is_arrayref is_hashref
                                    merge_attributes);
use File::DataClass::Constraints qw(Lock);
use MooseX::ClassAttribute;

use Class::Usul::L10N;
use Class::Usul::Log;
use IPC::SRLock;

class_has 'Lock' => is => 'rw',  isa => Lock;

has '_config'    => is => 'ro',  isa => ConfigType, coerce => TRUE,
   init_arg      => 'config', reader => 'config', required => TRUE;

has 'debug'      => is => 'rw',  isa => Bool, default => FALSE,
   trigger       => \&_debug_trigger;

has 'encoding'   => is => 'ro',  isa => EncodingType,
   documentation => 'Decode/encode input/output using this encoding',
   default       => sub { $_[ 0 ]->config->encoding }, lazy => TRUE;

has '_l10n'      => is => 'ro',  isa => Object,
   default       => sub { Class::Usul::L10N->new( builder => $_[ 0 ] ) },
   init_arg      => 'l10n', lazy => TRUE, reader => 'l10n';

has '_lock'      => is => 'ro',  isa => Lock, builder => '_build__lock',
   init_arg      => 'lock', lazy => TRUE, reader => 'lock';

has '_log'       => is => 'ro',  isa => LogType,
   default       => sub { Class::Usul::Log->new( builder => $_[ 0 ] ) },
   init_arg      => 'log',  lazy => TRUE, reader => 'log';

sub dumper {
   my $self = shift; return data_dumper( @_ ); # Damm handy for development
}

sub loc {
   my ($self, $params, $key, @rest) = @_; my $car = $rest[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @rest ] };

   $args->{domain_names} = [ DEFAULT_L10N_DOMAIN, $params->{namespace} ];
   $args->{locale      } = $params->{language};

   return $self->l10n->localize( $key, $args );
}

# Private methods

sub _build__lock {
   # There is only one lock object. Instantiate on first use
   my $self = shift; $self->Lock and return $self->Lock;

   my $config = $self->config; my $attrs = { %{ $config->lock_attributes } };

   merge_attributes $attrs, $self,   {}, [ qw(debug log) ];
   merge_attributes $attrs, $config, {}, [ qw(tempdir) ];

   return $self->Lock( IPC::SRLock->new( $attrs ) );
}

sub _debug_trigger {
   my ($self, $debug) = @_;

   $self->l10n->debug( $debug ); $self->lock->debug( $debug );

   return;
}

__PACKAGE__->meta->make_immutable;

no MooseX::ClassAttribute;
no Moose;

1;

__END__

=pod

=head1 Name

Class::Usul - A base class for program components

=head1 Version

Describes Class::Usul version 0.1.$Revision$

=head1 Synopsis

   use Class::Usul::Moose;

   extends qw(Class::Usul);

=head1 Description

These modules provide a set of base classes for a Perl applications

=head1 Configuration and Environment

   $self = Class::Usul->new( $attrs );

The C<$attrs> arg is a hash ref containing the object attributes.

=over 3

=item config

The C<config> attribute should be a hash ref that may define key/value pairs
that provide filesystem paths for the temporary directory etc.

=item debug

Defaults to false

=item encoding

Decode input and encode output. Defaults to I<UTF-8>

=back

Defines the lock object. This is readonly and instantiates on first use

Defined the application context log. Defaults to a L<Class::Null> object

=head1 Subroutines/Methods

=head2 dumper

   $self->dumper( $some_var );

Use L<Data::Printer> to dump arguments for development purposes

=head2 loc

   $local_text = $self->loc( $args, $key, $params );

Localizes the message. Calls L<Class::Usul::L10N/localize>

=head2 _build_lock

An L<IPC::SRLock> object which is used to single thread the
application where required. This is a singleton object.  Provides
defaults for and returns a new L<IPC::SRLock> object. The keys of the
C<< $self->lock_attributes >> hash are:

=over 3

=item debug

Debug status. Defaults to C<< $self->debug >>

=item log

Logging object. Defaults to C<< $self->log >>

=item tempdir

Directory used to store the lock file and lock table if the C<fcntl> backend
is used. Defaults to C<< $self->tempdir >>

=back

=head1 Diagnostics

Setting the I<debug> attribute to true causes messages to be logged at the
debug level

=head1 Dependencies

=over 3

=item L<Class::Usul::Constants>

=item L<Class::Usul::Constraints>

=item L<Class::Usul::Functions>

=item L<Class::Usul::L10N>

=item L<Class::Usul::Log>

=item L<Class::Usul::Moose>

=item L<File::DataClass::Constraints>

=item L<IPC::SRLock>

=item L<MooseX::ClassAttribute>

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
