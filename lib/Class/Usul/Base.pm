# @(#)$Id$

package Class::Usul::Base;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Time;
use Class::MOP;
use Class::Null;
use Digest qw();
use English qw(-no_match_vars);
use File::DataClass::IO ();
use File::Spec;
use List::Util qw(first);
use Moose::Role;
use Path::Class::Dir;
use Scalar::Util qw(blessed);
use TryCatch;

requires qw(Exception_Class);

sub app_prefix {
   (my $prefix = lc $_[1]) =~ s{ :: }{_}gmx; return $prefix;
}

sub arg_list {
   my ($self, @rest) = @_; $rest[0] or return {};

   return ref $rest[0] eq HASH ? { %{ $rest[0] } } : { @rest };
}

sub basename {
   my ($self, $path, @suffixes) = @_;

   return $self->io( $path )->basename( @suffixes );
}

sub catch {
   my ($self, @rest) = @_; return $self->exception_class->catch( @rest );
}

sub catdir {
   my ($self, @rest) = @_; return File::Spec->catdir( @rest );
}

sub catfile {
   my ($self, @rest) = @_; return File::Spec->catfile( @rest );
}

sub class2appdir {
   my ($self, $class) = @_; return lc $self->distname( $class );
}

sub classfile {
   my ($self, $class) = @_;

   return $self->catfile( split m{ :: }mx, $class.q(.pm) );
}

sub create_token {
   my ($self, $seed) = @_; my ($candidate, $digest, $digest_name);

   unless ($digest_name = __PACKAGE__->get_inherited( q(digest) )) {
      for $candidate (qw(SHA-256 SHA-1 MD5)) {
         last if ($digest = eval { Digest->new( $candidate ) });
      }

      $digest or $self->throw( 'No digest algorithm' );

      __PACKAGE__->set_inherited( q(digest), $candidate );
   }
   else { $digest = Digest->new( $digest_name ) }

   $digest->add( $seed || join q(), time, rand 10_000, $PID, {} );
   return $digest->hexdigest;
}

sub delete_tmp_files {
   my ($self, $dir) = @_;

   return $self->io( $dir || $self->tempdir )->delete_tmp_files;
}

sub dirname {
   my ($self, $path) = @_; return $self->io( $path )->dirname;
}

sub distname {
   (my $distname = $_[1]) =~ s{ :: }{-}gmx; return $distname;
}

sub ensure_class_loaded {
   my ($self, $class, $opts) = @_; $opts ||= {};

   my $package_defined = sub { Class::MOP::is_class_loaded( $class ) };

   return TRUE if (not $opts->{ignore_loaded} and $package_defined->());

   try        { Class::MOP::load_class( $class ) }
   catch ($e) { $self->throw( $e ) }

   return TRUE if ($package_defined->());

   my $e = 'Class [_1] loaded but package undefined';

   $self->throw( error => $e, args => [ $class ] );
   return;
}

sub env_prefix {
   my ($self, $class) = @_; return uc $self->app_prefix( $class );
}

sub escape_TT {
   (my $v = $_[1] || NUL) =~ s{ \[\% }{<%}gmx; $v =~ s{ \%\] }{%>}gmx;

   return $v;
}

sub exception_class {
   my $self = shift; return $self->Exception_Class;
}

sub find_source {
   my ($self, $class) = @_; my $file = $self->classfile( $class );

   for (@INC) {
      my $path = $self->catfile( $_, $file ); -f $path and return $path;
   }

   return;
}

sub home2appl {
   my $home = $_[1] or return;
   my $dir  = Path::Class::Dir->new( $home );

   $dir = $dir->parent while ($dir ne $dir->parent and $dir !~ m{ lib \z }mx);

   return $dir->parent;
}

sub io {
   my ($self, @rest) = @_; my $io = File::DataClass::IO->new( @rest );

   $io->exception_class( $self->exception_class );

   return $io;
}

sub is_member {
   my ($self, $candidate, @rest) = @_; $candidate or return;

   return (first { $_ eq $candidate } @rest) ? TRUE : FALSE;
}

sub load_component {
   my ($self, $child, @parents) = @_;

   ## no critic
   for my $parent (reverse @parents) {
      $self->ensure_class_loaded( $parent );
      {  no strict q(refs);

         unless ($child eq $parent or $child->isa( $parent )) {
            unshift @{ "${child}::ISA" }, $parent;
         }
      }
   }

   exists $Class::C3::MRO{ $child }
      or eval "package $child; import Class::C3;";
   ## critic
   return;
}

sub nap {
   my ($self, @rest) = @_; return Class::Usul::Time->nap( @rest );
}

sub say {
   my ($self, @rest) = @_; local ($OFS, $ORS) = ("\n", "\n"); chomp( @rest );

   return print {*STDOUT} @rest
      or $self->throw( error => 'IO error [_1]', args =>[ $ERRNO ] );
}

sub split_on__ {
   return (split m{ _ }mx, $_[1] || NUL)[ $_[2] || 0 ];
}

sub stamp {
   my ($self, @rest) = @_; return Class::Usul::Time->stamp( @rest );
}

sub status_for {
   my ($self, $path) = @_; return $self->io( $path )->stat;
}

sub str2date_time {
   my ($self, @rest) = @_; return Class::Usul::Time->str2date_time( @rest );
}

sub str2time {
   my ($self, @rest) = @_; return Class::Usul::Time->str2time( @rest );
}

sub strip_leader {
   (my $v = $_[1] || NUL) =~ s{ \A [^:]+ [:] \s+ }{}msx; return $v;
}

sub sub_name {
   my $level = $_[1] || 0; return (split m{ :: }mx, (caller ++$level)[3])[-1];
}

sub supports {
   my ($self, @spec) = @_; my $cursor = eval { $self->get_features } || {};

   return TRUE if (@spec == 1 and exists $cursor->{ $spec[0] });

   # Traverse the feature list
   for (@spec) {
      return FALSE unless (ref $cursor eq HASH); $cursor = $cursor->{ $_ };
   }

   return $cursor unless (ref $cursor);
   return FALSE   unless (ref $cursor eq ARRAY);

   # Check that all the keys required for a feature are in here
   for (@{ $cursor }) { return FALSE unless exists $self->{ $_ } }

   return TRUE;
}

sub tempfile {
   my ($self, $dir) = @_; return $self->io( $dir || $self->tempdir )->tempfile;
}

sub tempname {
   my ($self, $dir) = @_;

   my $file = sprintf '%6.6d%s', $PID, (substr $self->create_token, 0, 4);

   return $self->catfile( $dir || $self->tempdir, $file );
}

sub throw {
   my ($self, @rest) = @_; return $self->exception_class->throw( @rest );
}

sub throw_on_error {
   my ($self, @rest) = @_;

   return $self->exception_class->throw_on_error( @rest );
}

sub time2str {
   my ($self, @rest) = @_; return Class::Usul::Time->time2str( @rest );
}

sub unescape_TT {
   (my $v = $_[1] || NUL) =~ s{ \<\% }{[%}gmx; $v =~ s{ \%\> }{%]}gmx;

   return $v;
}

sub untaint_path {
   my ($self, $path) = @_;

   return $self->untaint_string( $path, UNTAINT_PATH_REGEX );
}

sub untaint_string {
   my ($self, $string, $untaint_regex) = @_; $string ||= NUL;

   my ($untainted) = $string =~ $untaint_regex;

   unless (defined $untainted and $untainted eq $string) {
      $self->throw( "String $string contains possible taint\n" );
   }

   return $untainted;
}

sub uuid {
   return shift->io( q(/proc/sys/kernel/random/uuid) )->lock->chomp->getline;
}

no Moose::Role;

1;

__END__

=pod

=head1 Name

Class::Usul::Base - Base class utility methods

=head1 Version

0.1.$Revision$

=head1 Synopsis

   package MyBaseClass;

   use base qw(Class::Usul::Base);

   sub new {
      my ($self, $app, $config) = @_;

      my $ac = $app->config || {};

      $config->{debug  } ||= $app->debug    || 0;
      $config->{log    } ||= $app->log      || Class::Null->new();
      $config->{tempdir} ||= $ac->{tempdir} || File::Spec->tmpdir;

      return $self->next::method( $app, $config );
   }

=head1 Description

Provides utility methods to the application base class

=head1 Subroutines/Methods

=head2 app_prefix

   $prefix = $self->app_prefix( __PACKAGE__ );

Takes a class name and returns it lower cased with B<::> changed to
B<_>, e.g. C<App::Munchies> becomes C<app_munchies>

=head2 arg_list

   $args = $self->arg_list( @rest );

Returns a hash ref containing the passed parameter list. Enables
methods to be called with either a list or a hash ref as it's input
parameters

=head2 basename

   $basename = $self->basename( $path, @suffixes );

Returns the L<base name|File::Basename/basename> of the passed path

=head2 catch

   $e = $self->catch;

Expose the C<catch> method in the error class L<Class::Usul::Exception>

=head2 catdir

   $dir_path = $self->catdir( $part1, $part2 );

Expose L<File::Spec/catdir>

=head2 catfile

   $file_path = $self->catfile( $dir_path, $file_name );

Expose L<File::Spec/catfile>

=head2 class2appdir

   $appdir = $self->class2appdir( __PACKAGE__ );

Returns lower cased L</distname>, e.g. C<App::Munchies> becomes
C<app-munchies>

=head2 classfile

   $path = $self->classfile( __PACKAGE__ );

Returns the path/file name plus extension of a given class. Uses
L<File::Spec> for portability, e.g. C<App::Munchies> becomes
C<App/Munchies.pm>

=head2 create_token

   $random_hex = $self->create_token( $seed );

Create a random string token using the first available L<Digest>
algorithm. If C<$seed> is defined then add that to the digest,
otherwise add some random data. Returns a hexadecimal string

=head2 delete_tmp_files

   $self->delete_tmp_files( $dir );

Delete this processes temporary files. Files are in the C<$dir> directory
which defaults to C<< $self->tempdir >>

=head2 dirname

   $dirname = $self->dirname( $path );

Returns the L<directory name|File::Basename/dirname> of the passed path

=head2 distname

   $distname = $self->distname( __PACKAGE__ );

Takes a class name and returns it with B<::> changed to
B<->, e.g. C<App::Munchies> becomes C<App-Munchies>

=head2 ensure_class_loaded

   $self->ensure_class_loaded( $some_class );

Require the requested class, throw an error if it doesn't load

=head2 env_prefix

   $prefix = $self->env_prefix( $class );

Returns upper cased C<app_prefix>. Suitable as prefix for environment
variables

=head2 escape_TT

   $text = $self->escape_TT( q([% some_stash_key %]) );

The left square bracket causes problems in some contexts. Substitute a
less than symbol instead. Also replaces the right square bracket with
greater than for balance. L<Template::Toolkit> will work with these
sequences too, so unescaping isn't absolutely necessary

=head2 exception_class

Return the exception class. Used by the action class to process
exceptions

=head2 find_source

   $path = $self->find_source( $module_name );

Find the source code for the given module

=head2 home2appl

   $appldir = $self->home2appl( $home_dir );

Strips the trailing C<lib/my_package> from the supplied directory path

=head2 io

   $io_obj = $self->io( $pathname );

Expose the methods in L<File::DataClass::IO>

=head2 is_member

   $bool = $self->is_member( q(test_value), qw(a_value test_value b_value) );

Tests to see if the first parameter is present in the list of
remaining parameters

=head2 load_component

   $self->load_component( $child, @parents );

Ensures that each component is loaded then fixes @ISA for the child so that
it inherits from the parents

=head2 mk_accessors

   $self->mk_accessors( @fieldspec );

Create accessors methods like L<Class::Accessor::Fast> but using
L<Class::Accessor::Grouped>

=head2 nap

   $self->nap( $time_in_seconds );

Exposes the L<nap|Class::Usul::Time/nap> method which sleeps for
(possibly fractional) periods of time

=head2 say

   $self->say( @lines_of_text );

Prints to I<STDOUT> the lines of text passed to it. Lines are C<chomp>ed
and then have newlines appended. Throws on IO errors

=head2 split_on__

   $field = $self->split_on__( $string, $field_no );

Splits string by _ (underscore) and returns the requested field. Defaults
to field zero

=head2 stamp

   $time_date_string = $self->stamp( $time );

Exposes the L<stamp|Class::Usul::Time/stamp> method which returns an ISO format date/time string. Defaults to the current time if C<$time> is omitted

=head2 status_for

   $stat_ref = $self->status_for( $path );

Return a hash for the given path containing it's inode status information

=head2 str2date_time

   $date_time_obj = $self->str2date_time( $date_time_string );

Exposes the L<str2date_time|Class::Usul::Time/str2date_time>
method which returns a L<DateTime> object representing the supplied
date/time string

=head2 str2time

   $seconds = $self->str2time( $date_time_string );

Exposes L<str2time|Class::Usul::Time/str2time> method which returns
the number of seconds elapsed since the epoch for the supplied date/time
string

=head2 strip_leader

   $stripped = $self->strip_leader( q(my_program: Error message) );

Strips the leading "program_name: whitespace" from the passed argument

=head2 sub_name

   $sub_name = $self->sub_name( $level );

Returns the name of the method that calls it

=head2 supports

   $bool = $self->supports( @spec );

Returns true if the hash returned by our I<get_features> attribute
contains all the elements of the required specification

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

=head2 throw

   $self->throw( error => q(error_key), args => [ q(error_arg) ] );

Expose L<Class::Usul::Exception/throw>

=head2 throw_on_error

   $self->throw_on_error;

Expose L<Class::Usul::Exception/throw_on_error>

=head2 time2str

   $date_time_string = $self->time2str( $format, $time );

Returns a date time string in the specified format

=head2 unescape_TT

   $text = $self->unescape_TT( q(<% some_stash_key %>) );

Do the reverse of C<escape_TT>

=head2 untaint_path

   $untainted_path = $self->untaint_path( $maybe_tainted_path );

Returns an untainted file path. Call L</untaint_string> with the


=head2 untaint_string

   $untainted_string = $self->untaint_string( $maybe_tainted_string, $regex );

Returns an untainted string

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

=item L<Class::Usul::Exception>

=item L<Class::Usul::Time>

=item L<Class::Accessor::Grouped>

=item L<Class::MOP>

=item L<Digest>

=item L<File::DataClass::IO>

=item L<File::Temp>

=item L<List::Util>

=item L<Path::Class::Dir>

=back

=head1 Incompatibilities

The C<home2appl> method is dependent on the installation path
containing a B<lib>

The C</uuid> method with only work on a OS with a F</proc> filesystem

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
