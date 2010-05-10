# @(#)$Id$

package Class::Usul::Build::InstallActions;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Constants;
use File::Copy qw(copy move);
use File::Path qw(make_path);
use File::Find qw(find);
use TryCatch;
use Moose;

has 'actions' => is => 'ro', isa => 'ArrayRef',
   default    => sub {
      [ qw(create_dirs create_files copy_files link_files
           create_schema create_ugrps set_owner
           set_permissions make_default restart_server) ] };
has 'builder' => is => 'ro', isa => 'Object', required => TRUE,
   handles    => [ qw(cli installation_destination module_name) ];

sub copy_files {
   # Copy some files
   my ($self, $cfg) = @_; my $cli = $self->cli; my $base = $cfg->{base};

   for my $ref (@{ $cfg->{copy_files} }) {
      my $from = $self->_abs_path( $base, $ref->{from} );
      my $path = $self->_abs_path( $base, $ref->{to  } );

      if (-f $from and not -f $path) {
         $cli->info( "Copying $from to $path" );
         copy( $from, $path );
         chmod oct q(0644), $path;
      }
   }

   return;
}

sub create_dirs {
   # Create some directories that don't ship with the distro
   my ($self, $cfg) = @_; my $cli = $self->cli; my $base = $cfg->{base};

   for my $dir (map { $self->_abs_path( $base, $_ ) }
                @{ $cfg->{create_dirs} }) {
      if (-d $dir) { $cli->info( "Directory $dir exists" ) }
      else {
         $cli->info( "Creating $dir" );
         make_path( $dir, { mode => oct q(02750) } );
      }
   }

   return;
}

sub create_files {
   # Create some empty log files
   my ($self, $cfg) = @_; my $cli = $self->cli; my $base = $cfg->{base};

   for my $path (map { $self->_abs_path( $base, $_ ) }
                 @{ $cfg->{create_files} }) {
      unless (-f $path) {
         $cli->info( "Creating $path" ); $cli->io( $path )->touch;
      }
   }

   return;
}

sub create_schema {
   # Create databases and edit credentials
   my ($self, $cfg) = @_; my $cli = $self->cli;

   # Edit the XML config file that contains the database connection info
   $self->_edit_credentials( $cfg );

   my $bind = $self->install_destination( q(bin) );
   my $cmd  = $cli->catfile( $bind, $cfg->{prefix}.q(_schema) );

   # Create the database if we can. Will do nothing if we can't
   $cli->info( $cli->run_cmd( $cmd.q( -n -c create_database) )->out );

   # Call DBIx::Class::deploy to create the
   # schema and populate it with static data
   $cli->info( 'Deploying schema and populating database' );
   $cli->info( $cli->run_cmd( $cmd.q( -n -c deploy_and_populate) )->out );
   return;
}

sub create_ugrps {
   # Create the two groups used by this application
   my ($self, $cfg) = @_; my $cli = $self->cli; my $base = $cfg->{base};

   my $cmd = q(/usr/sbin/groupadd); my $text;

   if (-x $cmd) {
      # Create the application group
      for my $grp ($cfg->{group}, $cfg->{admin_role}) {
         unless (getgrnam $grp ) {
            $cli->info( "Creating group $grp" );
            $cli->run_cmd( $cmd.q( ).$grp );
         }
      }
   }

   $cmd = q(/usr/sbin/usermod);

   if (-x $cmd and $cfg->{process_owner}) {
      # Add the process owner user to the application group
      $cmd .= ' -a -G'.$cfg->{group}.q( ).$cfg->{process_owner};
      $cli->run_cmd( $cmd );
   }

   $cmd = q(/usr/sbin/useradd);

   if (-x $cmd and not getpwnam $cfg->{owner}) {
      # Create the user to own the files and support the application
      $cli->info( 'Creating user '.$cfg->{owner} );
      ($text = ucfirst $self->module_name) =~ s{ :: }{ }gmx;
      $cmd .= ' -c "'.$text.' Support" -d ';
      $cmd .= $cli->dirname( $base ).' -g '.$cfg->{group}.' -G ';
      $cmd .= $cfg->{admin_role}.' -s ';
      $cmd .= $cfg->{shell}.q( ).$cfg->{owner};
      $cli->run_cmd( $cmd );
   }

   return;
}

sub link_files {
   # Link some files
   my ($self, $cfg) = @_; my $cli = $self->cli; my $base = $cfg->{base};

   for my $ref (@{ $cfg->{link_files} }) {
      my $from = $self->_abs_path( $base, $ref->{from} ) || NUL;
      my $path = $self->_abs_path( $base, $ref->{to  } ) || NUL;

      if ($from and $path) {
         if (-e $from) {
            -l $path and unlink $path;

            unless (-e $path) {
               $cli->info( "Symlinking $from to $path" );
               symlink $from, $path;
            }
            else { $cli->info( "Path $path already exists" ) }
         }
         else { $cli->info( "Path $from does not exist" ) }
      }
      else { $cli->info( "Path from $from or to $path undefined" ) }
   }

   return;
}

sub make_default {
   # Create the default version symlink
   my ($self, $cfg) = @_; my $cli = $self->cli;

   my $base = $cfg->{base}; my $verdir = $cli->basename( $base );

   $cli->info( "Making $verdir the default version" );
   chdir $cli->dirname( $base );
   -e q(default) and unlink q(default);
   symlink $verdir, q(default);
   return;
}

sub restart_server {
   # Bump start the web server
   my ($self, $cfg) = @_; my $cli = $self->cli;

   my $cmd  = $cfg->{restart_server_cmd};
   my $prog = (split SPC, $cmd)[0];

   return unless ($cmd and -x $prog);

   $cli->info( "Server restart, running $cmd" );
   $cli->run_cmd( $cmd );
   return;
}

sub set_owner {
   # Now we have created everything and have an owner and group
   my ($self, $cfg) = @_; my $cli = $self->cli; my $base = $cfg->{base};

   my $gid = $cfg->{gid} = getgrnam( $cfg->{group} ) || 0;
   my $uid = $cfg->{uid} = getpwnam( $cfg->{owner} ) || 0;
   my $text;

   $text  = 'Setting owner '.$cfg->{owner}."($uid) and group ";
   $text .= $cfg->{group}."($gid)";
   $cli->info( $text );

   # Set ownership
   chown $uid, $gid, $cli->dirname( $base );
   find( sub { chown $uid, $gid, $_ }, $base );
   chown $uid, $gid, $base;
   return;
}

sub set_permissions {
   # Set permissions
   my ($self, $cfg) = @_; my $cli = $self->cli;

   my $base = $cfg->{base}; my $pref = $cfg->{prefix};

   chmod oct q(02750), $cli->dirname( $base );

   find( sub { if    (-d $_)                { chmod oct q(02750), $_ }
               elsif ($_ =~ m{ $pref _ }mx) { chmod oct q(0750),  $_ }
               else                         { chmod oct q(0640),  $_ } },
         $base );

   $cfg->{create_dirs} or return;

   # Make the shared directories group writable
   for my $dir (grep { -d $_ }
                map  { $self->_abs_path( $base, $_ ) }
                @{ $cfg->{create_dirs} }) {
      chmod oct q(02770), $dir;
   }

   return;
}

# Private methods

sub _abs_path {
   my ($self, $base, $path) = @_; my $cli = $self->cli;

   $cli->io( $path )->is_absolute or $path = $cli->catfile( $base, $path );

   return $path;
}

sub _edit_credentials {
   my ($self, $cfg) = @_; my $value;

   my $dbname = $cfg->{database_name} or return;

   return unless ($cfg->{credentials} and $cfg->{credentials}->{ $dbname });

   my $cli         = $self->cli;
   my $etcd        = $cli->catdir ( $cfg->{base}, qw(var etc) );
   my $path        = $cli->catfile( $etcd, $dbname.q(.xml) );
   my $data        = $cli->data_load( path => $path );
   my $credentials = $cfg->{credentials}->{ $dbname };

   for my $field (qw(driver host port user password)) {
      defined ($value = $credentials->{ $field }) or next;
      $data->{credentials}->{ $dbname }->{ $field } = $value;
   }

   try        { $cli->data_dump( data => $data, path => $path ) }
   catch ($e) { $cli->fatal( $e ) }

   return;
}

1;

__END__

=pod

=head1 Name

Class::Usul::Build::InstallActions - Things to do after Build install

=head1 Version

Describes Class::Usul::Build::InstallActions version 0.1.$Revision$

=head1 Synopsis

=head1 Description

=head1 Subroutines/Methods

All action methods are passed C<$config>

=head2 copy_files

Copies files as defined in the C<< $config->{copy_files} >> attribute.
Each item in this list is a hash ref containing I<from> and I<to> keys

=head2 create_dirs

Create the directory paths specified in the list
C<< $config->{create_dirs} >> if they do not exist

=head2 create_files

Create the files specified in the list
C<< $config->{create_files} >> if they do not exist

=head2 create_schema

Creates a database then deploys and populates the schema

=head2 create_ugrps

Creates the user and group to own the application files

=head2 link_files

Creates some symbolic links

=head2 make_default

Makes this installation the default for this server

=head2 restart_server

Restarts the web server

=head2 set_owner

Set the ownership of the installed files and directories

=head2 set_permissions

Set the permissions on the installed files and directories

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Build>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

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
