package Class::Usul;

use 5.010001;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.57.%d', q$Rev: 5 $ =~ /\d+/gmx );

use Moo;
use Class::Usul::Constants  qw( EXCEPTION_CLASS FALSE TRUE );
use Class::Usul::Functions  qw( data_dumper merge_attributes );
use Class::Usul::L10N;
use Class::Usul::Log;
use Class::Usul::Types      qw( Bool ConfigType EncodingType HashRef
                                L10NType LoadableClass LockType LogType );
use IPC::SRLock;

# Construction
my $_build_lock = sub {
   my $self   = shift;
   my $config = $self->config;
   my $attr   = { %{ $config->lock_attributes } };

   merge_attributes $attr, $self,   {}, [ 'debug', 'log' ];
   merge_attributes $attr, $config, { 'exception_class' => EXCEPTION_CLASS },
                                    [ 'exception_class', 'tempdir' ];

   return IPC::SRLock->new( $attr );
};

# Public attributes
has 'config'       => is => 'lazy', isa => ConfigType, builder => sub {
   $_[ 0 ]->config_class->new( $_[ 0 ]->_config_attr ) },
   init_arg        => undef;

has '_config_attr' => is => 'ro',   isa => HashRef, builder => sub { {} },
   init_arg        => 'config';

has 'config_class' => is => 'ro',   isa => LoadableClass, coerce => TRUE,
   default         => 'Class::Usul::Config';

has 'debug'        => is => 'lazy', isa => Bool, default => FALSE;

has 'encoding'     => is => 'lazy', isa => EncodingType,
   builder         => sub { $_[ 0 ]->config->encoding };

has 'l10n'         => is => 'lazy', isa => L10NType,
   builder         => sub { Class::Usul::L10N->new( builder => $_[ 0 ] ) },
   handles         => [ 'localize' ];

has 'lock'         => is => 'lazy', isa => LockType, builder => $_build_lock;

has 'log'          => is => 'lazy', isa => LogType,
   builder         => sub { Class::Usul::Log->new( builder => $_[ 0 ] ) };

# Public methods
sub dumper { # Damm handy for development
   my $self = shift; return data_dumper( @_ );
}

1;

__END__

=pod

=head1 Name

Class::Usul - A base class providing config, locking, logging, and l10n

=head1 Version

Describes Class::Usul version v0.57.$Rev: 5 $

=head1 Synopsis

   use Class::Usul;
   use Class::Usul::Constants qw( FALSE );
   use Class::Usul::Functions qw( find_apphome get_cfgfiles );

   my $attr = { config => {}, debug => $ENV{DEBUG} // FALSE };
   my $conf = $attr->{config};

   $conf->{appclass    } or  die "Application class not specified";
   $attr->{config_class} //= $conf->{appclass}.'::Config';
   $conf->{home        }   = find_apphome $conf->{appclass};
   $conf->{cfgfiles    }   = get_cfgfiles $conf->{appclass}, $conf->{home};

   return Class::Usul->new( $attr );

=head1 Description

These modules provide a set of base classes for Perl modules and
applications. It provides configuration file loading
L<Class::Usul::Config>, locking to single thread processes
L<IPC::SRLock>, logging L<Class::Usul::Log> and localisation
L<Class::Usul::L10N>

The class L<Class::Usul::Programs> is a base class for command line interfaces

Interprocess communication is handled by L<Class::Usul::IPC>

L<Class::Usul::File> makes the functionality of L<File::DataClass> available

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item config

The C<config> attribute should be a hash reference that may define key / value
pairs that provide filesystem paths for the temporary directory etc.

=item config_class

Defaults to L<Class::Usul::Config> and is of type C<LoadableClass>. An
instance of this class is loaded and instantiated using the hash reference
in the C<config> attribute. It provides accessor methods with symbol
inflation and smart defaults. Add configuration attributes by
subclassing this class

=item debug

Defaults to false

=item encoding

Decode input and encode output. Defaults to C<< $self->config->encoding >>
which defaults to to C<UTF-8>

=item l10n

An instance of L<Class::Usul::L10N>

=item lock

An instance of L<IPC::SRLock>

=item log

An instance of L<Class::Usul::Log>

=back

=head1 Subroutines/Methods

=head2 dumper

   $self->dumper( $some_var );

Use L<Data::Printer> to dump arguments for development purposes

=head1 Diagnostics

Setting the I<debug> attribute to true causes messages to be logged at the
debug level

=head1 Dependencies

=over 3

=item L<Class::Usul::Constants>

=item L<Class::Usul::Functions>

=item L<Class::Usul::L10N>

=item L<Class::Usul::Log>

=item L<IPC::SRLock>

=item L<Moo>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 Acknowledgements

Larry Wall - For the Perl programming language

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
