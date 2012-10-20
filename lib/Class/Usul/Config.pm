# @(#)$Id$

package Class::Usul::Config;

use strict;
use version; our $VERSION = qv( sprintf '0.8.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::File;
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions       qw(app_prefix class2appdir home2appldir
                                    is_arrayref split_on__ untaint_path);
use Config;
use English                      qw(-no_match_vars);
use File::Basename               qw(basename dirname);
use File::DataClass::Constraints qw(Directory File Path);
use File::Gettext::Constants;
use File::Spec::Functions        qw(canonpath catdir catfile rel2abs tmpdir);

has 'appclass'        => is => 'ro',   isa => NonEmptySimpleStr,
   required           => TRUE;

has 'doc_title'       => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'User Contributed Documentation';

has 'encoding'        => is => 'ro',   isa => EncodingType, coerce => TRUE,
   default            => DEFAULT_ENCODING;

has 'extension'       => is => 'ro',   isa => NonEmptySimpleStr,
   default            => CONFIG_EXTN;

has 'home'            => is => 'ro',   isa => Directory, coerce => TRUE,
   documentation      => 'Directory containing the config file',
   required           => TRUE;

has 'l10n_attributes' => is => 'ro',   isa => HashRef, default => sub { {} };

has 'lock_attributes' => is => 'ro',   isa => HashRef, default => sub { {} };

has 'log_attributes'  => is => 'ro',   isa => HashRef, default => sub { {} };

has 'man_page_cmd'    => is => 'ro',   isa => ArrayRef,
   default            => sub { [ qw(nroff -man) ] };

has 'mode'            => is => 'ro',   isa => PositiveInt, default => MODE;

has 'no_thrash'       => is => 'ro',   isa => PositiveInt, default => 3;

has 'pathname'        => is => 'lazy', isa => File, coerce => TRUE;


has 'appldir'         => is => 'lazy', isa => Directory, coerce => TRUE;

has 'binsdir'         => is => 'lazy', isa => Path,      coerce => TRUE;

has 'ctlfile'         => is => 'lazy', isa => Path,      coerce => TRUE;

has 'ctrldir'         => is => 'lazy', isa => Path,      coerce => TRUE;

has 'dbasedir'        => is => 'lazy', isa => Path,      coerce => TRUE;

has 'localedir'       => is => 'lazy', isa => Directory, coerce => TRUE;

has 'logfile'         => is => 'lazy', isa => Path,      coerce => TRUE;

has 'logsdir'         => is => 'lazy', isa => Directory, coerce => TRUE;

has 'root'            => is => 'lazy', isa => Path,      coerce => TRUE;

has 'rundir'          => is => 'lazy', isa => Path,      coerce => TRUE;

has 'sessdir'         => is => 'lazy', isa => Path,      coerce => TRUE;

has 'shell'           => is => 'lazy', isa => File,      coerce => TRUE;

has 'suid'            => is => 'lazy', isa => Path,      coerce => TRUE;

has 'tempdir'         => is => 'lazy', isa => Directory, coerce => TRUE;

has 'vardir'          => is => 'lazy', isa => Path,      coerce => TRUE;


has 'name'            => is => 'lazy', isa => NonEmptySimpleStr;

has 'owner'           => is => 'lazy', isa => NonEmptySimpleStr;

has 'phase'           => is => 'lazy', isa => PositiveInt;

has 'prefix'          => is => 'lazy', isa => NonEmptySimpleStr;

has 'salt'            => is => 'lazy', isa => NonEmptySimpleStr;

has 'script'          => is => 'lazy', isa => NonEmptySimpleStr;

around 'BUILDARGS' => sub {
   my ($next, $class, @args) = @_; my $attr = $class->$next( @args ); my $paths;

   if ($paths = delete $attr->{cfgfiles} and $paths->[ 0 ]) {
      my $loaded = Class::Usul::File->data_load
         ( paths => $paths, storage_class => q(Any), );

      $attr = { %{ $loaded || {} }, %{ $attr } };
   }

   for my $attr_name (keys %{ $attr }) {
      defined $attr->{ $attr_name }
          and $attr->{ $attr_name } =~ m{ \A __([^\(]+?)__ \z }mx
          and $attr->{ $attr_name } = $class->_inflate_symbol( $attr, $1 );
   }

   for my $attr_name (keys %{ $attr }) {
      defined $attr->{ $attr_name }
          and $attr->{ $attr_name } =~ m{ \A __(.+?)\((.+?)\)__ \z }mx
          and $attr->{ $attr_name } = $class->_inflate_path( $attr, $1, $2 );
   }

   return $attr;
};

sub canonicalise {
   my ($self, $base, $relpath) = @_;

   my @base = ((is_arrayref $base) ? @{ $base } : $base);
   my @rest = split m{ / }mx, $relpath;
   my $path = canonpath( untaint_path catdir( @base, @rest ) );

   -d $path and return $path;

   return canonpath( untaint_path catfile( @base, @rest ) );
}

# Private methods

sub _build_appldir {
   my ($self, $appclass, $home) = __unpack( @_ ); my $dir = home2appldir $home;

   -d catdir( $dir, q(bin) )
      or $dir = catdir( NUL, q(var), (class2appdir $appclass) );

   -d $dir or $dir = home2appldir $home;

   return rel2abs( untaint_path $dir );
}

sub _build_binsdir {
   my ($self, $attr) = @_;

   my $dir = $self->_inflate_path( $attr, qw(appldir bin) );

   return -d $dir ? $dir : untaint_path $Config{installsitescript};
}

sub _build_ctlfile {
   my ($self, $attr) = @_; my $file = $self->name.$self->extension;

   return $self->_inflate_path( $attr, q(ctrldir), $file );
}

sub _build_ctrldir {
   my $dir = $_[ 0 ]->_inflate_path( $_[ 1 ], qw(vardir etc) );

   return -d $dir ? $dir : $_[ 0 ]->_inflate_path( $_[ 1 ], q(vardir) );
}

sub _build_dbasedir {
   my $dir =  $_[ 0 ]->_inflate_path( $_[ 1 ], qw(vardir db) );

   return -d $dir ? $dir : $_[ 0 ]->_inflate_path( $_[ 1 ], q(vardir) );
}

sub _build_localedir {
   my ($self, $attr) = @_;

   my $dir = $self->_inflate_path( $attr, qw(vardir locale) );

   -d $dir and return $dir;

   for (map { catdir( @{ $_ } ) } @{ DIRECTORIES() } ) { -d $_ and return $_ }

   return $self->_inflate_path( $attr, qw(tempdir) );
}

sub _build_logfile {
   return $_[ 0 ]->_inflate_path( $_[ 1 ], q(logsdir), $_[ 0 ]->name.q(.log) );
}

sub _build_logsdir {
   my ($self, $attr) = @_;

   my $dir = $self->_inflate_path( $attr, qw(vardir logs) );

   return -d $dir ? $dir : $self->_inflate_path( $attr, qw(tempdir) );
}

sub _build_name {
   my $prog = basename( $_[ 0 ]->pathname, EXTNS );

   return (split_on__ $prog, 1) || $prog;
}

sub _build_owner {
   return $_[ 0 ]->prefix || q(root);
}

sub _build_pathname {
   return rel2abs( (q(-) eq substr $PROGRAM_NAME, 0, 1) ? $EXECUTABLE_NAME
                                                        : $PROGRAM_NAME );
}

sub _build_path_to {
   my ($self, $appclass, $home) = __unpack( @_ ); return $home;
}

sub _build_phase {
   my ($self, $attr) = @_;

   my $verdir  = blessed $self ? basename( $self->appldir )
               : basename( $self->_inflate_path( $attr, q(appldir) ) );
   my ($phase) = $verdir =~ m{ \A v \d+ \. \d+ p (\d+) \z }msx;

   return defined $phase ? $phase : PHASE;
}

sub _build_prefix {
   return (split m{ :: }mx, lc $_[ 0 ]->appclass)[ -1 ];
}

sub _build_root {
   my $dir = $_[ 0 ]->_inflate_path( $_[ 1 ], qw(vardir root) );

   return -d $dir ? $dir : $_[ 0 ]->_inflate_path( $_[ 1 ], q(vardir) );
}

sub _build_rundir {
   my $dir = $_[ 0 ]->_inflate_path( $_[ 1 ], qw(vardir run) );

   return -d $dir ? $dir : $_[ 0 ]->_inflate_path( $_[ 1 ], q(vardir) );
}

sub _build_script {
   return basename( $_[ 0 ]->pathname );
}

sub _build_salt {
   return $_[ 0 ]->prefix;
}

sub _build_sessdir {
   my $dir = $_[ 0 ]->_inflate_path( $_[ 1 ], qw(vardir hist) );

   return -d $dir ? $dir : $_[ 0 ]->inflate_path( $_[ 1 ], q(vardir) );
}

sub _build_shell {
   my $file = catfile( NUL, qw(bin ksh) ); -f $file and return $file;

   $file = $ENV{SHELL}; -f $file and return $file;

   return catfile( NUL, qw(bin sh) );
}

sub _build_suid {
   my ($self, $attr) = @_; my $file = $self->prefix.q(_admin);

   return $self->_inflate_path( $attr, q(binsdir), $file );
}

sub _build_tempdir {
   my $dir = $_[ 0 ]->_inflate_path( $_[ 1 ], qw(vardir tmp) );

   return -d $dir ? $dir : untaint_path tmpdir;
}

sub _build_vardir {
   my ($self, $attr) = @_;

   my $dir = $self->_inflate_path( $attr, qw(appldir var) );

   return -d $dir ? $dir : $self->_inflate_path( $attr, q(appldir) );
}

sub _inflate_path {
   my ($self, $attr, $symbol, $relpath) = @_; $attr ||= {};

   my $inflated = $self->_inflate_symbol( $attr, $symbol );

   $relpath or return canonpath( untaint_path $inflated );

   return $self->canonicalise( $inflated, $relpath );
}

sub _inflate_symbol {
   my ($self, $attr, $symbol) = @_; $attr ||= {};

   my $attr_name = lc $symbol; my $method = q(_build_).$attr_name;

   return blessed $self                      ? $self->$attr_name()
        : __is_inflated( $attr, $attr_name ) ? $attr->{ $attr_name }
                                             : $self->$method( $attr );
}

# Private functions

sub __is_inflated {
   my ($attr, $attr_name) = @_;

   return exists $attr->{ $attr_name } && defined $attr->{ $attr_name }
       && $attr->{ $attr_name } !~ m{ \A __ }mx ? TRUE : FALSE;
}

sub __unpack {
   my ($self, $attr) = @_; $attr ||= {};

   blessed $self and return ($self, $self->appclass, $self->home);

   return ($self, $attr->{appclass}, $attr->{home});
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

Class::Usul::Config - Inflate config values

=head1 Version

Describes Class::Usul::Config version 0.8.$Revision$

=head1 Synopsis

=head1 Description

Defines the following list of attributes

=over 3

=item C<appclass>

Required string. The classname of the application for which this is the
configuration class

=item C<doc_title>

String defaults to 'User Contributed Documentation'. Used in the Unix man
pages

=item C<encoding>

String default to the constant I<DEFAULT_ENCODING>

=item C<extension>

String defaults to the constant I<CONFIG_EXTN>

=item C<home>

Directory containing the config file. Required

=item C<l10n_attributes>

Hash ref of attributes used to construct a L<Class::Usul::L10N> object

=item C<lock_attributes>

Hash ref of attributes used to construct an L<IPC::SRLock> object

=item C<log_attributes>

Hash ref of attributes used to construct a L<Class::Usul::Log> object

=item C<man_page_cmd>

Array ref containing the command and options to produce a man page. Defaults
to I<man -nroff>

=item C<mode>

Integer defaults to the constant I<PERMS>. The default file creation mask

=item C<no_thrash>

Integer default to 3. Number of seconds to sleep in a polling loop to
avoid processor thrash

=item C<pathname>

File defaults to the absolute path to the I<PROGRAM_NAME> system constant

=item C<appldir>

Directory. Defaults to the application's install directory

=item C<binsdir>

Directory. Defaults to the application's I<bin> directory

=item C<ctlfile>

File in the C<ctrldir> directory that contains this programs control data

=item C<ctrldir>

Directory containing the per program configuration files

=item C<dbasedir>

Directory containing the data file used to create the applications database

=item C<localedir>

Directory containing the GNU Gettext portable object files used to translate
messages into different languages

=item C<logfile>

File in the C<logsdir> to which this program will log

=item C<logsdir>

Directory containing the application log files

=item C<root>

Directory. Path to the web applications document root

=item C<rundir>

Directory. Contains a running programs PID file

=item C<sessdir>

Directory. The session directory

=item C<shell>

File. The default shell used to create new OS users

=item C<suid>

File. Name of the setuid root program in the I<bin> directory. Defaults to
the I<prefix>_admin

=item C<tempdir>

Directory. It is the location of any temporary files created by the
application. Defaults to the L<File::Spec> tempdir

=item C<vardir>

Directory. Contains all of the non program code directories

=item C<name>

String. Name of the program

=item C<owner>

String. Name of the application file owner

=item C<phase>

Integer. Phase number indicates the type of install, e.g. 1 live, 2 test,
3 development

=item C<prefix>

String. Program prefix

=item C<script>

String. The basename of the I<pathname> attribute

=item C<salt>

String. This applications salt for passwords as set by the administrators . It
is used to perturb the encryption methods. Defaults to the I<prefix>
attribute value

=back

=head1 Subroutines/Methods

=head2 BUILDARGS

Loads the configuration files if specified. Calls L</inflate_symbol>
and L</inflate_path>

=head2 canonicalise

   $untainted_canonpath = $self->canonicalise( $base, $relpath );

Appends C<$relpath> to C<$base> using L<File::Spec::Functions>. The C<$base>
argument can be an array ref or a scalar. The C<$relpath> argument must be
separated by slashes. The return path is untainted and canonicalised

=head2 _inflate_path

Inflates the I<__symbol( relative_path )__> values to their actual runtime
values

=head2 _inflate_symbol

Inflates the I<__SYMBOL__> values to their actual runtime values

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::File>

=item L<Class::Usul::Moose>

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
