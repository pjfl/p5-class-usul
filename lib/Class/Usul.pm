# @(#)$Id$

package Class::Usul;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use 5.010;
use Moose;
use Class::MOP;
use Class::Usul::Constants;
use Class::Usul::Constraints     qw(ConfigType EncodingType LogType);
use Class::Usul::Functions       qw(data_dumper is_arrayref is_hashref
                                    merge_attributes throw);
use Class::Usul::L10N;
use Class::Usul::Log;
use File::DataClass::Constraints qw(Lock);
use IPC::SRLock;
use Module::Pluggable::Object;
use MooseX::ClassAttribute;
use MooseX::Types::Moose         qw(Bool Object);
use Scalar::Util                 qw(blessed);
use Try::Tiny;

class_has 'Lock' => is => 'rw',    isa => Lock;

has '_config'    => is => 'ro',    isa => ConfigType, coerce   => TRUE,
   reader        => 'config', init_arg => 'config',   required => TRUE;

has 'debug'      => is => 'rw',    isa => Bool,       default  => FALSE,
   trigger       => \&_debug_set;

has 'encoding'   => is => 'ro',    isa => EncodingType,
   documentation => 'Decode/encode input/output using this encoding',
   lazy          => TRUE,      builder => '_build_encoding';

has '_l10n'      => is => 'ro',    isa => Object,
   lazy          => TRUE,      builder => '_build__l10n',
   reader        => 'l10n',   init_arg => 'l10n';

has '_lock'      => is => 'ro',    isa => Lock,
   lazy          => TRUE,      builder => '_build__lock',
   reader        => 'lock',   init_arg => 'lock';

has '_log'       => is => 'ro',    isa => LogType,
   lazy          => TRUE,      builder => '_build__log',
   reader        => 'log',    init_arg => 'log';

sub dumper {
   my $self = shift; return data_dumper( @_ ); # Damm handy for development
}

sub ensure_class_loaded {
   my ($self, $class, $opts) = @_; $opts ||= {};

   my $package_defined = sub { Class::MOP::is_class_loaded( $class ) };

   not $opts->{ignore_loaded} and $package_defined->() and return TRUE;

   try { Class::MOP::load_class( $class ) } catch { throw $_ };

   $package_defined->()
      or throw error => 'Class [_1] loaded but package undefined',
               args  => [ $class ];

   return TRUE;
}

sub load_component {
   my ($self, $child, @parents) = @_;

   ## no critic
   for my $parent (reverse @parents) {
      $self->ensure_class_loaded( $parent );
      {  no strict q(refs);

         $child eq $parent or $child->isa( $parent )
            or unshift @{ "${child}::ISA" }, $parent;
      }
   }

   exists $Class::C3::MRO{ $child } or eval "package $child; import Class::C3;";
   ## critic
   return;
}

sub loc {
   my ($self, $params, $key, @rest) = @_; my $car = $rest[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @rest ] };

   $args->{domain_names} = [ DEFAULT_L10N_DOMAIN, $params->{ns} ];
   $args->{locale      } = $params->{lang};

   return $self->l10n->localize( $key, $args );
}

sub setup_plugins {
   # Searches for and then load plugins in the search path
   my ($self, $config) = @_; my $class = blessed $self || $self;

   my $exclude = delete $config->{ exclude_pattern } || q(\A \z);
   my @paths   = @{ delete $config->{ search_paths } || [] };
   my $finder  = Module::Pluggable::Object->new
      ( search_path => [ map { m{ \A :: }mx ? __PACKAGE__.$_ : $_ } @paths ],
        %{ $config } );
   my @plugins = grep { not m{ $exclude }mx }
                 sort { length $a <=> length $b } $finder->plugins;

   $self->load_component( $class, @plugins );

   return \@plugins;
}

sub supports {
   my ($self, @spec) = @_; my $cursor = eval { $self->get_features } || {};

   @spec == 1 and exists $cursor->{ $spec[ 0 ] } and return TRUE;

   # Traverse the feature list
   for (@spec) {
      is_hashref $cursor or return FALSE; $cursor = $cursor->{ $_ };
   }

   ref $cursor or return $cursor; is_arrayref $cursor or return FALSE;

   # Check that all the keys required for a feature are in here
   for (@{ $cursor }) { exists $self->{ $_ } or return FALSE }

   return TRUE;
}

# Private methods

sub _build_encoding {
   my $self = shift; return $self->config->encoding;
}

sub _build__l10n {
   my $self = shift; return Class::Usul::L10N->new( ioc => $self );
}

sub _build__lock {
   # There is only one lock object. Instantiate on first use
   my $self  = shift; $self->Lock and return $self->Lock;

   my $cfg   = $self->config; my $attrs = { %{ $cfg->lock_attributes } };

   merge_attributes $attrs, $self, {}, [ qw(debug log) ];
   merge_attributes $attrs, $cfg,  {}, [ qw(tempdir) ];

   return $self->Lock( IPC::SRLock->new( $attrs ) );
}

sub _build__log {
   my $self = shift; return Class::Usul::Log->new( ioc => $self );
}

sub _debug_set {
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

   use Moose;

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

=head2 ensure_class_loaded

   $self->ensure_class_loaded( $some_class );

Require the requested class, throw an error if it doesn't load

=head2 load_component

   $self->load_component( $child, @parents );

Ensures that each component is loaded then fixes @ISA for the child so that
it inherits from the parents

=head2 loc

   $local_text = $self->loc( $args, $key, $params );

Localizes the message. Calls L<Class::Usul::L10N/localize>

=head2 setup_plugins

   @plugins = $self->setup_plugins( $class, $config_ref );

Load the given list of plugins and have the supplied class inherit from them.
Returns an array ref of available plugins

=head2 supports

   $bool = $self->supports( @spec );

Returns true if the hash returned by our I<get_features> attribute
contains all the elements of the required specification

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

=item L<Class::MOP>

=item L<Class::Usul::Constants>

=item L<Class::Usul::Constraints>

=item L<Class::Usul::Functions>

=item L<Class::Usul::L10N>

=item L<File::DataClass::Constraints>

=item L<IPC::SRLock>

=item L<Log::Handler>

=item L<Module::Pluggable::Object>

=item L<Moose>

=item L<MooseX::ClassAttribute>

=item L<MooseX::Types::Moose>

=item L<Try::Tiny>

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
