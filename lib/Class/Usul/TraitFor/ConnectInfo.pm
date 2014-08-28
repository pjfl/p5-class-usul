package Class::Usul::TraitFor::ConnectInfo;

use 5.010001;
use feature 'state';
use namespace::autoclean;

use Class::Usul::Constants   qw( EXCEPTION_CLASS CONFIG_EXTN FALSE TRUE );
use Class::Usul::Crypt::Util qw( decrypt_from_config );
use Class::Usul::File;
use Class::Usul::Functions   qw( merge_attributes throw );
use File::Spec::Functions    qw( catfile );
use Scalar::Util             qw( blessed );
use Unexpected::Functions    qw( Unspecified );
use Moo::Role;

requires qw( config ); # As a class method

sub dump_config_data {
   my ($self, $config, $db, $cfg_data) = @_;

   my $params = $self->_merge_attributes( $config, { database => $db } );

   return __dump_config_data( $params, $cfg_data );
}

sub extract_creds_from {
   my ($self, $config, $db, $cfg_data) = @_;

   my $params = $self->_merge_attributes( $config, { database => $db } );

   return __extract_creds_from( $params, $cfg_data );
}

sub get_connect_info {
   my ($self, $app, $params) = @_; $app //= $self; $params //= {};

   merge_attributes $params, $app->config, $self->config, __connect_info_attr();

   my $class    = $params->{class} = blessed $self || $self;
   my $key      = __get_connect_info_cache_key( $params );

   state $cache //= {}; defined $cache->{ $key } and return $cache->{ $key };

   my $cfg_data = __load_config_data( $params );
   my $creds    = __extract_creds_from( $params, $cfg_data );
   my $dsn      = 'dbi:'.$creds->{driver}.':database='.$params->{database}
                  .';host='.$creds->{host}.';port='.$creds->{port};
   my $password = decrypt_from_config( $params, $creds->{password} );
   my $opts     = __get_connect_options( $creds );

   return $cache->{ $key } = [ $dsn, $creds->{user}, $password, $opts ];
}

sub load_config_data {
   my ($self, $config, $db) = @_;

   my $params = $self->_merge_attributes( $config, { database => $db } );

   return __load_config_data( $params );
}

# Private methods
sub _merge_attributes {
   return merge_attributes { class => blessed $_[ 0 ] || $_[ 0 ] },
                  $_[ 1 ], ($_[ 2 ] || {}), __connect_info_attr();
}

# Private functions
sub __connect_info_attr {
   return [ qw( class ctlfile ctrldir database dataclass_attr extension
                prefix read_secure salt seed seed_file subspace tempdir ) ];
}

sub __dump_config_data {
   my ($params, $cfg_data) = @_;

   my $ctlfile = __get_credentials_file( $params );
   my $schema  = __get_dataclass_schema( $params->{dataclass_attr} );

   return $schema->dump( { data => $cfg_data, path => $ctlfile } );
}

sub __extract_creds_from {
   my ($params, $cfg_data) = @_;

   my $key = __get_connect_info_cache_key( $params );

   ($cfg_data->{credentials} and defined $cfg_data->{credentials}->{ $key })
      or throw error => 'Path [_1] database [_2] no credentials',
               args  => [ __get_credentials_file( $params ), $key ];

   return $cfg_data->{credentials}->{ $key };
}

sub __get_connect_info_cache_key {
   my $params = shift;
   my $db     = $params->{database}
      or throw error => 'Class [_1] has no database name',
               args  => [ $params->{class} ];

   return $params->{subspace} ? "${db}.".$params->{subspace} : $db;
}

sub __get_connect_options {
   my $creds = shift;
   my $uopt  = $creds->{unicode_option}
            || __unicode_options()->{ lc $creds->{driver} } || {};

   return { AutoCommit =>  $creds->{auto_commit  } // TRUE,
            PrintError =>  $creds->{print_error  } // FALSE,
            RaiseError =>  $creds->{raise_error  } // TRUE,
            %{ $uopt }, %{ $creds->{database_attr} || {} }, };
}

sub __get_credentials_file {
   my $params = shift; my $ctlfile = $params->{ctlfile};

   defined $ctlfile and -f $ctlfile and return $ctlfile;

   my $dir = $params->{ctrldir}; my $db = $params->{database};

      $dir or throw class => Unspecified, args => [ 'ctrldir' ];
   -d $dir or throw error => 'Directory [_1] not found', args => [ $dir ];
       $db or throw error => 'Class [_1] has no database name',
                    args  => [ $params->{class} ];

   return catfile( $dir, $db.($params->{extension} || CONFIG_EXTN) );
}

sub __get_dataclass_schema {
   return Class::Usul::File->dataclass_schema( @_ );
}

sub __load_config_data {
   my $schema = __get_dataclass_schema( $_[ 0 ]->{dataclass_attr} );

   return $schema->load( __get_credentials_file( $_[ 0 ] ) );
}

sub __unicode_options {
   return { mysql  => { mysql_enable_utf8 => TRUE },
            pg     => { pg_enable_utf8    => TRUE },
            sqlite => { sqlite_unicode    => TRUE }, };
}

1;

=pod

=encoding utf8

=head1 Name

Class::Usul::TraitFor::ConnectInfo - Provides the DBIC connect info array ref

=head1 Synopsis

   package YourClass;

   use Moo;
   use Class::Usul::Constants;
   use Class::Usul::Types qw( NonEmptySimpleStr Object );

   with 'Class::Usul::TraitFor::ConnectInfo';

   has 'database' => is => 'ro', isa => NonEmptySimpleStr,
      default     => 'database_name';

   has 'schema' => is => 'lazy', isa => Object, builder => sub {
      my $self = shift; my $extra = $self->config->connect_params;
      $self->schema_class->connect( @{ $self->get_connect_info }, $extra ) };

   has 'schema_class' => is => 'ro', isa => NonEmptySimpleStr,
      default         => 'dbic_schema_class_name';

   sub config { # A class method
      return { ...config parameters... }
   }

=head1 Description

Provides the DBIC connect info array ref

=head1 Configuration and Environment

The JSON data looks like this:

  {
     "credentials" : {
        "schedule" : {
           "driver" : "mysql",
           "host" : "localhost",
           "password" : "{Twofish}U2FsdGVkX1/xcBKZB1giOdQkIt8EFgfNDFGm/C+fZTs=",
           "port" : "3306",
           "user" : "username"
        }
     }
   }

=head1 Subroutines/Methods

=head2 dump_config_data

   $dumped_data = $self->dump_config_data( $app_config, $db, $cfg_data );

Call the L<dump method|File::DataClass::Schema/dump> to write the
configuration file back to disk

=head2 extract_creds_from

   $creds = $self->extract_creds_from( $app_config, $db, $cfg_data );

Returns the credential info for the specified database and (optional)
subspace. The subspace attribute of C<$app_config> is appended
to the database name to create a unique cache key

=head2 get_connect_info

   $db_info_arr = $self->get_connect_info( $app_config, $db );

Returns an array ref containing the information needed to make a
connection to a database; DSN, user id, password, and options hash
ref. The data is read from the configuration file in the config
C<ctrldir>. Multiple sets of data can be stored in the same file,
keyed by the C<$db> argument. The password is decrypted if
required

=head2 load_config_data

   $cfg_data = $self->load_config_data( $app_config, $db );

Returns a hash ref of configuration file data. The path to the file
can be specified in C<< $app_config->{ctlfile} >> or it will default
to the C<$db.$extension> file in the C<< $app_config->{ctrldir} >>
directory.  The C<$extension> is either C<< $app_config->{extension} >>
or C<< $self->config->{extension} >> or the default extension given
by the C<CONFIG_EXTN> constant

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo::Role>

=item L<Class::Usul::Crypt::Util>

=item L<Unexpected>

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

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

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
