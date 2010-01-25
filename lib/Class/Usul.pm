# @(#)$Id$

package Class::Usul;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use 5.008;
use Class::Null;
use Class::Usul::Constants;
use File::DataClass::Exception;
use File::Spec;
use IPC::SRLock;
use Log::Handler;
use Module::Pluggable::Object;
use Moose;
use MooseX::ClassAttribute;

with qw(Class::Usul::Constraints File::DataClass::Constraints);

class_has 'Digest'          => is => 'rw', isa => 'C_U_Digest_Algorithm';
class_has 'Exception_Class' => is => 'rw', isa => 'F_DC_Exception',
   default                  => q(File::DataClass::Exception);
class_has 'Lock'            => is => 'rw', isa => 'F_DC_Lock';

has 'config'          => is => 'ro', isa => 'HashRef',
   default            => sub { {} };
has 'debug'           => is => 'rw', isa => 'Bool',
   default            => FALSE;
has 'encoding'        => is => 'rw', isa => 'C_U_Encoding',
   default            => q(UTF-8);
has 'lock'            => is => 'ro', isa => 'F_DC_Lock',
   lazy_build         => TRUE;
has 'lock_attributes' => is => 'ro', isa => 'HashRef',
   default            => sub { {} };
has 'log'             => is => 'ro', isa => 'C_U_Log',
   lazy_build         => TRUE;
has 'log_attributes'  => is => 'ro', isa => 'HashRef',
   default            => sub { { log_level => 6 } };
has 'prefix '         => is => 'ro', isa => 'Str',
   lazy_build         => TRUE;
has 'secret'          => is => 'ro', isa => 'Str',
   lazy_build         => TRUE;
has 'suid'            => is => 'ro', isa => 'F_DC_Path',
   coerce             => TRUE;
has 'tempdir'         => is => 'ro', isa => 'F_DC_Directory',
   default            => sub { __PACKAGE__->io( File::Spec->tmpdir ) },
   coerce             => TRUE;

with qw(Class::Usul::Base Class::Usul::Encoding Class::Usul::Crypt);

__PACKAGE__->mk_log_methods();

around BUILDARGS => sub {
   my ($orig, $class, @rest) = @_;

   my $attr   = $class->$orig( @rest );
   my $config = $attr->{config} ||= {};

   for (grep { defined $config->{ $_ } }
        __PACKAGE__->meta->get_attribute_list) {
      $attr->{ $_ } ||= $config->{ $_ };
   }

   return $attr;
};

sub build_subcomponents {
   # Voodo by mst. Finds and loads component subclasses
   my ($self, $base_class) = @_;

   my $my_class = blessed $self || $self; my $dir;

   ($dir = $self->find_source( $base_class )) =~ s{ \.pm \z }{}mx;

   for my $path (glob $self->catfile( $dir, q(*.pm) )) {
      my $subcomponent = $self->basename( $path, q(.pm) );
      my $component    = join q(::), $my_class,   $subcomponent;
      my $base         = join q(::), $base_class, $subcomponent;

      $self->load_component( $component, $base );
   }

   return;
}

sub setup_plugins {
   # Searches for and then load plugins in the search path
   my ($class, $config) = @_;

   my $exclude = delete $config->{ exclude_pattern } || q(\A \z);
   my @paths   = @{ delete $config->{ search_paths } || [] };
   my $finder  = Module::Pluggable::Object->new
      ( search_path => [ map { m{ \A :: }mx ? __PACKAGE__.$_ : $_ } @paths ],
        %{ $config } );
   my @plugins = grep { not m{ $exclude }mx }
                 sort { length $a <=> length $b } $finder->plugins;

   $class->load_component( $class, @plugins );

   return \@plugins;
}

sub udump {
   my ($self, @rest) = @_;

   require Data::Dumper;

   my $d = Data::Dumper->new( [ ref $self || $self, @rest ] );

   $d->Sortkeys( sub { return [ sort keys %{ $_[0] } ] } );
   $d->Indent( 1 ); $d->Useperl( 1 );
   warn $d->Dump;
   return;
}

# Private methods

sub _build_lock {
   my $self = shift;

   $self->Lock and return $self->Lock;

   my $attrs = $self->lock_attributes;

   $attrs->{debug  } ||= $self->debug;
   $attrs->{log    } ||= $self->log;
   $attrs->{tempdir} ||= $self->tempdir;

   return $self->Lock( IPC::SRLock->new( $attrs ) );
}

sub _build_log {
   my $self    = shift;
   my $attrs   = $self->log_attributes;
   my $logfile = $attrs->{logfile} || $self->config->{logfile} || NUL;
   my $dir     = $self->dirname( $logfile );

   return $logfile && -d $dir
        ? Log::Handler->new
        ( file      => {
           filename => $logfile,
           maxlevel => $self->debug ? 7 : $attrs->{log_level},
           mode     => q(append), } )
        : Class::Null->new;
}

sub _build_prefix {
   my $self = shift;

   return $self->split_on__( $self->basename( $self->suid ) );
}

sub _build_secret {
   my $self = shift; return $self->prefix;
}

__PACKAGE__->meta->make_immutable;

no MooseX::ClassAttribute;
no Moose;

1;

__END__

=pod

=head1 Name

Class::Usul - A base class for Catalyst MVC components

=head1 Version

Describes Class::Usul version 0.1.$Revision$

=head1 Synopsis

   use Moose;

   extends qw(Class::Usul);

=head1 Description

These modules provide a set of base classes for a Perl
applications

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 new

   $self = Class::Usul->new( $attrs, $app );

The C<$attrs> arg is a hash ref containing the object
attributes. An optional object refrence, C<$app>, that defines a
C<config> method can be supplied. The C<config> method should return a
hash ref that may define the following attributes:

=over 3

=item debug

The application context debug is used to set this. Defaults to false

=item encoding

The config supplies the encoding for the C<query_array>,
C<query_value> and log methods. Defaults to I<UTF-8>

=item lock

The lock object. This is readonly and instantiates on first use

=item log

The application context log. Defaults to a L<Class::Null> object

=item prefix

The prefix applied to executable programs in the I<bin>
directory. This is extracted from the I<suid> key in the config hash

=item secret

This applications secret key as set by the administrators in the
configuration. It is used to perturb the encryption methods. Defaults to
the I<prefix> attribute value

=item suid

Supplied by the config hash, it is the name of the setuid root
program in the I<bin> directory. Defaults to the null string

=item tempdir

Supplied by the config hash, it is the location of any temporary files
created by the application. Defaults to the L<File::Spec> tempdir

=back

The constructor applies these roles:

=over 3

=item L<Class::Usul::Base>

=item L<Class::Usul::Encoding>

=item L<File::DataClass::Constraints>

=back

=head2 build_subcomponents

   __PACKAGE__->build_subcomponents( $base_class );

Class method that allows us to define components that inherit from the base
class at runtime

=head2 setup_plugins

   @plugins = $self->setup_plugins( $class, $config_ref );

Load the given list of plugins and have the supplied class inherit from them.
Returns an array ref of available plugins

=head2 udump

   $self->udump( $object );

Calls L<Data::Dumper> with sane values for dumping objects for inspection

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

=item L<Class::Usul::Base>

=item L<Class::Usul::Encoding>

=item L<IPC::SRLock>

=item L<Module::Pluggable::Object>

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

Copyright (c) 2010 Peter Flanigan. All rights reserved

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

