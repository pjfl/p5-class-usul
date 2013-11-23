# @(#)$Ident: File.pm 2013-09-30 17:26 pjf ;

package Class::Usul::File;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.33.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions   qw( arg_list create_token is_arrayref throw );
use Class::Usul::Types       qw( BaseType );
use English                  qw( -no_match_vars );
use File::DataClass::Constants ( );
use File::DataClass::IO        ( );
use File::DataClass::Schema;
use File::Spec::Functions    qw( catdir catfile rootdir );
use Moo;
use Scalar::Util             qw( blessed );

File::DataClass::Constants->Exception_Class( EXCEPTION_CLASS );

# Private attributes
has '_usul' => is => 'ro', isa => BaseType,
   handles  => [ qw( config debug lock log ) ], init_arg => 'builder',
   required => TRUE, weak_ref => TRUE;

# Public methods
sub absolute {
   my ($self, $base, $path) = @_;

   $base //= rootdir; $path or return $self->io( $base );

   is_arrayref $base and $base = catdir( @{ $base } );

   return $self->io( $path )->absolute( $base );
}

sub data_dump {
   my ($self, @rest) = @_; my $args = arg_list @rest; my $attr = {};

   exists $args->{storage_class} and defined $args->{storage_class}
      and $attr->{storage_class} = delete $args->{storage_class};

   return $self->dataclass_schema( $attr )->dump( $args );
}

sub data_load {
   my ($self, @rest) = @_; my $args = arg_list @rest; my $attr = {};

   defined $args->{storage_class}
       and $attr->{storage_class} = delete $args->{storage_class};

   defined $args->{arrays}
       and $attr->{storage_attributes}->{force_array} = $args->{arrays};

  (is_arrayref $args->{paths} and defined $args->{paths}->[ 0 ])
      or throw 'No data file paths specified';

   return $self->dataclass_schema( $attr )->load( @{ $args->{paths} } );
}

sub dataclass_schema {
   my ($self, @rest) = @_; my $attr = arg_list @rest;

   if (blessed $self) { $attr->{builder} = $self->_usul }
   else { $attr->{cache_class} = 'none' }

   $attr->{storage_class} ||= 'Any';

   return File::DataClass::Schema->new( $attr );
}

sub delete_tmp_files {
   return $_[ 0 ]->io( $_[ 1 ] || $_[ 0 ]->tempdir )->delete_tmp_files;
}

sub extensions {
   return File::DataClass::Schema->extensions;
}

sub io {
   my $self = shift; return File::DataClass::IO->new( @_ );
}

sub status_for {
   return $_[ 0 ]->io( $_[ 1 ] )->stat;
}

sub symlink {
   my ($self, $base, $from, $to) = @_;

   $from or throw 'Symlink path from undefined';
   $from = $self->absolute( $base, $from );
   $from->exists or
      throw error => 'Path [_1] does not exist', args => [ $from->pathname ];
   $to or throw 'Symlink path to undefined';
   $to   = $self->io( $to ); -l $to->pathname and $to->unlink;
   $to->exists and
      throw error => 'Path [_1] already exists', args => [ $to->pathname ];
   CORE::symlink $from->pathname, $to->pathname or throw $OS_ERROR;
   return "Symlinked ${from} to ${to}";
}

sub tempdir {
   return $_[ 0 ]->config->tempdir;
}

sub tempfile {
   return $_[ 0 ]->io( $_[ 1 ] || $_[ 0 ]->tempdir )->tempfile;
}

sub tempname {
   my ($self, $dir) = @_; my $path;

   while (not $path or -f $path) {
      my $file = sprintf '%6.6d%s', $PID, (substr create_token, 0, 4);

      $path = catfile( $dir || $self->tempdir, $file );
   }

   return $path;
}

sub uuid {
   return $_[ 0 ]->io( $_[ 1 ] || UUID_PATH )->lock->chomp->getline;
}

1;

__END__

=pod

=head1 Name

Class::Usul::File - File and directory IO base class

=head1 Version

This documents version v0.33.$Rev: 1 $

=head1 Synopsis

   package MyBaseClass;

   use base qw(Class::Usul::File);

=head1 Description

Provides file and directory methods to the application base class

=head1 Subroutines/Methods

=head2 absolute

   $absolute_path = $self->absolute( $base, $path );

Prepends F<$base> to F<$path> unless F<$path> is an absolute path. The
C<$path> argument is passed to the L<File::DataClass::IO> constructor and
the C<$base> argument can be a string, object ref which stringifies, or an
array ref

=head2 data_dump

   $self->dump( @args );

Accepts either a list or a hash ref. Calls L</dataclass_schema> with
the I<storage_class> attribute if supplied. Calls the
L<dump|File::DataClass::Schema/dump> method

=head2 data_load

   $self->load( @args );

Accepts either a list or a hash ref. Calls L</dataclass_schema> with
the I<storage_class> and I<arrays> attributes if supplied. Calls the
L<load|File::DataClass::Schema/load> method

=head2 dataclass_schema

   $f_dc_schema_obj = $self->dataclass_schema( $attrs );

Returns a L<File::DataClass::Schema> object. Object uses our
C<exception_class>, no caching and no locking by default. Works as a
class method

=head2 delete_tmp_files

   $self->delete_tmp_files( $dir );

Delete this processes temporary files. Files are in the C<$dir> directory
which defaults to C<< $self->tempdir >>

=head2 extensions

   $hash_ref = $self->extensions;

Class method that returns the extensions supported by
L<File::DataClass::Storage>

=head2 io

   $io_obj = $self->io( $pathname );

Expose the methods in L<File::DataClass::IO>

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

The L</uuid> method with only work on a OS with a F</proc> filesystem

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
