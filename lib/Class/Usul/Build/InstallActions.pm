# @(#)$Id$

package Class::Usul::Build::InstallActions;

use strict;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions qw(class2appdir);
use File::Spec::Functions  qw(catdir);
use Try::Tiny;

has 'actions' => is => 'ro', isa => 'ArrayRef',
   default    => sub { [ qw(create_dirs create_files copy_files link_files
                            edit_files) ] };

has 'builder' => is => 'ro', isa => 'Object', required => TRUE,
   handles    => [ qw(base_dir cli _get_dest_base
                      install_destination _log_info module_name) ];

sub copy_files {
   # Copy some files without overwriting
   my ($self, $cfg) = @_; my $cli = $self->cli;

   for my $pair (@{ $cfg->{copy_files} }) {
      my $from = $cli->file->absolute( $self->base_dir, $pair->{from} );
      my $to   = $cli->file->absolute( $self->_get_dest_base( $cfg ),
                                       $pair->{to} );

      ($from->is_file and not -e $to->pathname) or next;
      $self->_log_info( "Copying ${from} to ${to}" );
      $from->copy( $to )->chmod( 0640 );
   }

   return;
}

sub create_dirs {
   # Create some directories that don't ship with the distro
   my ($self, $cfg) = @_; my $cli = $self->cli;

   my $base = $self->_get_dest_base( $cfg );

   for my $io (map { $cli->file->absolute( $base, $_ ) }
               @{ $cfg->{create_dirs} }) {
      if ($io->is_dir) { $self->_log_info( "Directory ${io} exists" ) }
      else { $self->_log_info( "Creating ${io}" ); $io->mkpath( oct q(02750) ) }
   }

   return;
}

sub create_files {
   # Create some empty log files
   my ($self, $cfg) = @_; my $cli = $self->cli;

   my $base = $self->_get_dest_base( $cfg );

   for my $io (map { $cli->file->absolute( $base, $_ ) }
               @{ $cfg->{create_files} }){
      unless ($io->is_file) { $self->_log_info( "Creating ${io}" ); $io->touch }
   }

   return;
}

sub edit_files {
   my ($self, $cfg) = @_; my $cli = $self->cli;

   # Fix hard coded path in suid program
   my $io   = $cli->io( [ $self->install_destination( q(bin) ),
                          $cli->config->prefix.q(_admin) ] );
   my $that = qr( \A use \s+ lib \s+ .* \z )msx;
   my $this = 'use lib q('.catdir( $cfg->{base}, q(lib) ).");\n";

   $io->is_file and $io->substitute( $that, $this )->chmod( 0555 );

   # Pointer to the application directory in /etc/default/<app dirname>
   $io   = $cli->io( [ NUL, qw(etc default),
                       class2appdir $self->module_name ] );
   $that = qr( \A APPLDIR= .* \z )msx;
   $this = q(APPLDIR=).$cfg->{base}."\n";

   $io->is_file and $io->substitute( $that, $this )->chmod( 0644 );
   return;
}

sub link_files {
   # Link some files
   my ($self, $cfg) = @_; my $cli = $self->cli;

   my $base = $self->_get_dest_base( $cfg ); my $msg;

   for my $link (@{ $cfg->{link_files} }) {
      try   { $msg = $cli->file->symlink( $base, $link->{from}, $link->{to} ) }
      catch { $msg = NUL.$_ };

      $self->_log_info( $msg );
   }

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

=head2 edit_files



=head2 link_files

Creates some symbolic links

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
