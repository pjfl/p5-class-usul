# @(#)$Id$

package Class::Usul::Build::Questions;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Constants;
use Moose;
use IO::Interactive qw(is_interactive);

has 'builder'           => is => 'ro', isa => 'Object', required => TRUE,
   handles              => [ qw(cli) ];
has 'config_attributes' => is => 'ro', isa => 'ArrayRef',
   default              => sub {
      [ qw(ask style path_prefix ver phase create_ugrps
           process_owner setuid_root create_schema credentials
           run_cmd make_default restart_server
           restart_server_cmd built) ] };
has 'paragraph'         => is => 'ro', isa => 'HashRef',
   default              => sub { { cl => TRUE, fill => TRUE, nl => TRUE } };
has 'prefix_normal'     => is => 'ro', isa => 'ArrayRef',
   default              => sub { [ NUL, qw(opt) ] };
has 'prefix_perl'       => is => 'ro', isa => 'ArrayRef',
   default              => sub { [ NUL, qw(var www) ] };

sub q_ask {
   my ($self, $cfg) = @_; is_interactive or return FALSE;

   return $self->cli->yorn( 'Ask questions during build', TRUE, TRUE, 0 );
}

sub q_built {
   return TRUE;
}

sub q_create_schema {
   my ($self, $cfg) = @_; my $create = $cfg->{create_schema} || FALSE;

   return $create unless ($cfg->{ask} and $cfg->{database});

   my $cli  = $self->cli;
   my $text = 'Schema creation requires a database, id and password';

   $cli->output( $text, $self->paragraph );

   return $cli->yorn( 'Create database schema', $create, TRUE, 0 );
}

sub q_create_ugrps {
   my ($self, $cfg) = @_; my $create = $cfg->{create_ugrps} || FALSE;

   $cfg->{ask} or return $create; my $cli = $self->cli; my $text;

   $cfg->{owner     } ||= $cli->app_prefix( $self->builder->module_name );
   $cfg->{group     } ||= $cfg->{owner};
   $cfg->{admin_role} ||= q(admin);

   $text  = 'Use groupadd, useradd, and usermod to create the user ';
   $text .= $cfg->{owner}.' and the groups '.$cfg->{group};
   $text .= ' and '.$cfg->{admin_role};
   $cli->output( $text, $self->paragraph );

   return $cli->yorn( 'Create groups and user', $create, TRUE, 0 );
}

sub q_credentials {
   my ($self, $cfg) = @_; my $credentials = $cfg->{credentials} || {};

   return $credentials
      unless ($cfg->{ask} and $cfg->{create_schema} and $cfg->{database_name});

   my $cli     = $self->cli;
   my $name    = $cfg->{database_name};
   my $etcd    = $cli->catdir ( $self->builder->base_dir, qw(var etc) );
   my $path    = $cli->catfile( $etcd, $name.q(.xml) );
   my $dbcfg   = $cli->data_load( path => $path );
   my $prompts = { name     => 'Enter db name',
                   driver   => 'Enter DBD driver',
                   host     => 'Enter db host',
                   port     => 'Enter db port',
                   user     => 'Enter db user',
                   password => 'Enter db password' };
   my $defs    = { name     => $name,
                   driver   => q(_field),
                   host     => q(localhost),
                   port     => q(_field),
                   user     => q(_field),
                   password => NUL };

   for my $fld (qw(name driver host port user password)) {
      my $value = $defs->{ $fld } eq q(_field)
                ? $dbcfg->{credentials}->{ $name }->{ $fld }
                : $defs->{ $fld };

      $value = $cli->get_line( $prompts->{ $fld }, $value, TRUE, 0, FALSE,
                               $fld eq q(password) ? TRUE : FALSE );
      $fld eq q(password) and $value = $self->_encrypt( $cfg, $value, $etcd );
      $credentials->{ $name }->{ $fld } = $value;
   }

   return $credentials;
}

sub q_make_default {
   my ($self, $cfg) = @_; my $make_default = $cfg->{make_default} || FALSE;

   $cfg->{ask} or return $make_default;

   my $text = 'Make this the default version';

   return $self->cli->yorn( $text, $make_default, TRUE, 0 );
}

sub q_path_prefix {
   my ($self, $cfg) = @_; my $cli  = $self->cli;

   my $default = $cfg->{style} && $cfg->{style} eq q(normal)
               ? $self->prefix_normal : $self->prefix_perl;
   my $prefix  = $cfg->{path_prefix} || $cli->catdir( @{ $default } );

   $cfg->{ask} or return $prefix;

   my $text = 'Application name is automatically appended to the prefix';

   $cli->output( $text, $self->paragraph );

   return $cli->get_line( 'Enter install path prefix', $prefix, TRUE, 0 );
}

sub q_phase {
   my ($self, $cfg) = @_; my $phase = $cfg->{phase} || PHASE;

   $cfg->{ask} or return $phase; my $cli = $self->cli; my $text;

   $text  = 'Phase number determines at run time the purpose of the ';
   $text .= 'application instance, e.g. live(1), test(2), development(3)';
   $cli->output( $text, $self->paragraph );
   $phase = $cli->get_line( 'Enter phase number', $phase, TRUE, 0 );
   $phase =~ m{ \A \d+ \z }mx
      or $cli->fatal( "Phase value $phase bad (not an integer)" );

   return $phase;
}

sub q_process_owner {
   my ($self, $cfg) = @_; my $user = $cfg->{process_owner} || q(www-data);

   return $user unless ($cfg->{ask} and $cfg->{create_ugrps});

   my $cli = $self->cli; my $text;

   $text  = 'Which user does the application or web server/proxy run as? ';
   $text .= 'This user will be added to the application group so that ';
   $text .= 'it can access the application\'s files';
   $cli->output( $text, $self->paragraph );

   return $cli->get_line( 'Process owner', $user, TRUE, 0 );
}

sub q_restart_server {
   my ($self, $cfg) = @_; my $restart = $cfg->{restart_server} || FALSE;

   $cfg->{ask} or return $restart;

   return $self->cli->yorn( 'Restart server', $restart, TRUE, 0 );
}

sub q_restart_server_cmd {
   my ($self, $cfg) = @_; my $cmd = $cfg->{restart_server_cmd} || NUL;

   return $cmd unless ($cfg->{ask} and $cfg->{restart_server});

   return $self->cli->get_line( 'Server restart command', $cmd, TRUE, 0, TRUE );
}

sub q_run_cmd {
   my ($self, $cfg) = @_; my $run = $cfg->{run_cmd} || FALSE;

   $cfg->{ask} or return $run; my $cli = $self->cli; my $text;

   $text  = 'Execute post installation commands. These may take ';
   $text .= 'several minutes to complete';
   $cli->output( $text, $self->paragraph );

   return $cli->yorn( 'Post install commands', $run, TRUE, 0 );
}

sub q_setuid_root {
   my ($self, $cfg) = @_; my $setuid = $cfg->{setuid_root} || FALSE;

   $cfg->{ask} or return $setuid; my $cli = $self->cli; my $text;

   $text  = 'Enable wrapper which allows limited access to some root ';
   $text .= 'only functions like password checking and user management';
   $cli->output( $text, $self->paragraph );

   return $cli->yorn( 'Enable suid root', $setuid, TRUE, 0 );
}

sub q_style {
   my ($self, $cfg) = @_; my $style = $cfg->{style} || q(normal);

   $cfg->{ask} or return $style; my $cli = $self->cli; my $text;

   $text  = 'The application has two modes if installation. In *normal* ';
   $text .= 'mode it installs all components to a specifed path. In ';
   $text .= '*perl* mode modules are installed to the site lib, ';
   $text .= 'executables to the site bin and the rest to a subdirectory ';
   $text .= 'of /var/www. Installation defaults to normal mode since it is ';
   $text .= 'easier to maintain';
   $cli->output( $text, $self->paragraph );

   return $cli->get_line( 'Enter the install mode', $style, TRUE, 0 );
}

sub q_ver {
   my $self = shift; (my $ver = $self->builder->dist_version) =~ s{ \A v }{}mx;

   my ($major, $minor) = split m{ \. }mx, $ver;

   return $major.q(.).$minor;
}

sub _encrypt {
   my ($self, $cfg, $value, $dir) = @_;

   $value or return; my $cli = $self->cli; my $path;

   my $args = { seed => $cfg->{secret} || $cfg->{prefix} };

   $dir and $path = $cli->catfile( $dir, $cfg->{prefix}.q(.txt) );
   $path and -f $path and $args->{data} = $cli->io( $path )->all;
   $value = $cli->encrypt( $args, $value );
   $value and $value = q(encrypt=).$value;

   return $value;
}

1;

__END__

=pod

=head1 Name

Class::Usul::Build::Questions - Things to ask when Build runs

=head1 Version

Describes Class::Usul::Build::Questions version 0.1.$Revision$

=head1 Synopsis

=head1 Description

All question methods are passed C<$config> and return the new value
for one of it's attributes

=head1 Subroutines/Methods

=head2 q_ask

Ask if questions should be asked in future runs of the build process

=head2 q_built

Always returns true. This dummy question is used to trigger the suppression
of any further questions once the build phase is complete

=head2 q_create_schema

Should a database schema be created? If yes then the database connection
information must be entered. The database must be available at install
time

=head2 q_create_ugrps

Create the application user and group that owns the files and directories
in the application

=head2 q_credentials

Get the database connection information

=head2 q_make_default

When installed should this installation become the default for this
host? Causes the symbolic link (that hides the version directory from
the C<PATH> environment variable) to be deleted and recreated pointing
to this installation

=head2 q_path_prefix

Prompt for the installation prefix. The application name and version
directory are automatically appended. If the installation style is
B<normal>, the all of the application will be installed to this
path. The default is F</opt>. If the installation style is B<perl>
then only the "var" data will be installed to this path. The default is
F</var/www>

=head2 q_phase

The phase number represents the reason for the installation. It is
encoded into the name of the application home directory. At runtime
the application will load some configuration data that is dependent
upon this value

=head2 q_process_owner

Prompts for the userid of the web server process owner. This user will
be added to the group that owns the application files and directories.
This will allow the web server processes to read and write these files

=head2 q_restart_server

When the application is mostly installed, should the web server be
restarted?

=head2 q_restart_server_cmd

What is the command used to restart the web server

=head2 q_run_cmd

Run the post installation commands? These may take a long time to complete

=head2 q_setuid_root

Enable the C<setuid> root wrapper?

=head2 q_style

Which installation layout? Either B<perl> or B<normal>

=over 3

=item B<normal>

Modules, programs, and the F<var> directory tree are installed to a
user selectable path. Defaults to F<< /opt/<appname> >>

=item B<perl>

Will install modules and programs in their usual L<Config> locations. The
F<var> directory tree will be install to F<< /var/www/<appname> >>

=back

=head2 q_ver

Dummy question returns the version part of the installation directory

=head1 Diagnostics

None

=head1 Configuration and Environment

Edits and stores config information in the file F<build.xml>

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
