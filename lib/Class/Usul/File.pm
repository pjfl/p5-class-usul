# @(#)$Id$

package Class::Usul::File;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use Class::Usul::Constants;
use Class::Usul::Constraints qw(ConfigType);
use Class::Usul::Functions   qw(arg_list classfile create_token is_arrayref
                                throw untaint_path);
use English                  qw(-no_match_vars);
use File::DataClass::Constants ();
use File::DataClass::IO        ();
use File::DataClass::Schema;
use File::Spec;
use Scalar::Util             qw(blessed);

has 'config' => is => 'ro', isa => ConfigType, required => TRUE;

File::DataClass::Constants->Exception_Class( EXCEPTION_CLASS );

sub abs_path {
   my ($self, $base, $path) = @_; $base ||= NUL; $path or return NUL;

   is_arrayref $base and $base = File::Spec->catdir( $base );

   return $self->io( $path )->absolute( $base );
}

sub data_dump {
   my ($self, @rest) = @_;

   return $self->dataclass_schema->dump( arg_list @rest );
}

sub data_load {
   my ($self, @rest) = @_; my $args = arg_list @rest;

   $args = { path => $args->{path} || NUL,
             storage_attributes => { _arrays => $args->{arrays} || {} } };

   return $self->dataclass_schema( $args )->load;
}

sub dataclass_schema {
   my ($self, $attr) = @_; $attr = { %{ $attr || {} } };

   if (blessed $self) { $attr->{ioc_obj} = $self }
   else { $attr->{cache_class} = q(none); $attr->{lock_class} = q(none) }

   return File::DataClass::Schema->new( $attr );
}

sub delete_tmp_files {
   return $_[ 0 ]->io( $_[ 1 ] || $_[ 0 ]->tempdir )->delete_tmp_files;
}

sub find_source {
   my ($self, $class) = @_; my $file = classfile $class;

   for (@INC) {
      my $path = File::Spec->catfile( $_, $file ); -f $path and return $path;
   }

   return;
}

sub io {
   my $self = shift; return File::DataClass::IO->new( @_ );
}

{  my $cache;

   sub read_post_install_config {
      my $self  = shift; defined $cache and return $cache;

      my $cfg   = $self->config;
      my $attrs = { storage_attributes => {
                           force_array => $cfg->{pi_arrays} } };
      my $path  = File::Spec->catfile( $cfg->ctrldir,
                                       $cfg->{pi_config_file} );

      return $cache = $self->dataclass_schema( $attrs )->load( $path );
   }
}

sub status_for {
   return $_[ 0 ]->io( $_[ 1 ] )->stat;
}

sub symlink {
   my ($self, $base, $from, $to) = @_;

   $from or throw 'Symlink path from undefined';
   $from = $self->abs_path( $base, $from );
   $from->exists or
      throw error => 'Path [_1] does not exist', args => [ $from->pathname ];
   $to or throw 'Symlink path to undefined';
   $to   = $self->io( $to ); -l $to->pathname and $to->unlink;
   $to->exists and
      throw error => 'Path [_1] already exists', args => [ $to->pathname ];
   CORE::symlink $from->pathname, $to->pathname or throw $ERRNO;
   return "Symlinked ${from} to ${to}";
}

sub tempdir {
   return untaint_path( $_[ 0 ]->config->tempdir || File::Spec->tmpdir );
}

sub tempfile {
   return $_[ 0 ]->io( $_[ 1 ] || $_[ 0 ]->tempdir )->tempfile;
}

sub tempname {
   my ($self, $dir) = @_; my $path;

   while (not $path or -f $path) {
      my $file = sprintf '%6.6d%s', $PID, (substr create_token, 0, 4);

      $path = File::Spec->catfile( $dir || $self->tempdir, $file );
   }

   return $path;
}

sub uuid {
   return $_[ 0 ]->io( $_[ 1 ] || UUID_PATH )->lock->chomp->getline;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

Class::Usul::File - File and directory IO base class

=head1 Version

0.6.$Revision$

=head1 Synopsis

   package MyBaseClass;

   use base qw(Class::Usul::File);

=head1 Description

Provides file and directory methods to the application base class

=head1 Subroutines/Methods

=head2 abs_path

   $absolute_path = $self->_abs_path( $base, $path );

Prepends F<$base> to F<$path> unless F<$path> is an absolute path

=head2 data_dump

=head2 data_load

=head2 delete_tmp_files

   $self->delete_tmp_files( $dir );

Delete this processes temporary files. Files are in the C<$dir> directory
which defaults to C<< $self->tempdir >>

=head2 dataclass_schema

   $f_dc_schema_obj = $self->dataclass_schema( $attrs );

Returns a L<File::DataClass::Schema> object. Object uses our
C<exception_class>, no caching and no locking

=head2 find_source

   $path = $self->find_source( $module_name );

Find the source code for the given module

=head2 io

   $io_obj = $self->io( $pathname );

Expose the methods in L<File::DataClass::IO>

=head2 read_post_install_config

   $picfg_hash_ref = $self->read_post_install_config;

Returns a hash ref of the post installation config which was written to
the control directory during the installation process

=head2 status_for

   $stat_ref = $self->status_for( $path );

Return a hash for the given path containing it's inode status information

=head2 symlink

   $out_ref = $self->symlink( $base, $from, $to );

Creates a symlink. If either C<$from> or C<$to> is a relative path then
C<$base> is prepended to make it absolute. Returns a message indicating
success or throws an exception on failure

=head2 tempdir

   $temporary_directory = $self->tempdir;

Returns C<< $self->config->tempdir >> or L<File::Spec/tmpdir>

=head2 tempfile

   $tempfile_obj = $self->tempfile( $dir );

Returns a L<File::Temp> object in the C<$dir> directory
which defaults to C<< $self->tempdir >>. File is automatically deleted
if the C<$tempfile_obj> reference goes out of scope

=head2 tempname

   $pathname = $self->tempname( $dir );

Returns the pathname of a temporary file in the given directory which
defaults to C<< $self->tempdir >>. The file will be deleted by
L</delete_tmp_files> if it is called otherwise it will persist

=head2 uuid

   $uuid = $self->uuid;

Return the contents of F</proc/sys/kernel/random/uuid>

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Constants>

=item L<File::DataClass::IO>

=item L<File::Temp>

=back

=head1 Incompatibilities

The C</uuid> method with only work on a OS with a F</proc> filesystem

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