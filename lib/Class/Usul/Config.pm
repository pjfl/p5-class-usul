# @(#)$Id$

package Class::Usul::Config;

use strict;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::File;
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Constraints     qw(EncodingType);
use Class::Usul::Functions       qw(app_prefix class2appdir
                                    home2appl split_on__ untaint_path);
use English                      qw(-no_match_vars);
use File::Basename               qw(basename dirname);
use File::DataClass::Constraints qw(Directory File Path);
use File::Gettext::Constants;
use File::Spec::Functions        qw(canonpath catdir catfile rel2abs tmpdir);
use Config;

has 'appclass'        => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

has 'doc_title'       => is => 'ro', isa => NonEmptySimpleStr,
   default            => 'User Contributed Documentation';

has 'encoding'        => is => 'ro', isa => EncodingType, coerce => TRUE,
   default            => DEFAULT_ENCODING;

has 'extension'       => is => 'ro', isa => NonEmptySimpleStr,
   default            => CONFIG_EXTN;

has 'home'            => is => 'ro', isa => Directory, coerce => TRUE,
   documentation      => 'Directory containing the config file',
   required           => TRUE;

has 'l10n_attributes' => is => 'ro', isa => HashRef, default => sub { {} };

has 'lock_attributes' => is => 'ro', isa => HashRef, default => sub { {} };

has 'log_attributes'  => is => 'ro', isa => HashRef, default => sub { {} };

has 'man_page_cmd'    => is => 'ro', isa => ArrayRef,
   default            => sub { [ qw(nroff -man) ] };

has 'mode'            => is => 'ro', isa => PositiveInt, default => PERMS;

has 'no_thrash'       => is => 'ro', isa => PositiveInt, default => 3;

has 'pathname'        => is => 'ro', isa => File, coerce => TRUE,
   builder            => '_build_pathname', lazy => TRUE;


has 'appldir'         => is => 'ro', isa => Directory, coerce => TRUE,
   lazy               => TRUE,   builder => '_build_appldir';

has 'binsdir'         => is => 'ro', isa => Path,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_binsdir';

has 'ctlfile'         => is => 'ro', isa => Path,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_ctlfile';

has 'ctrldir'         => is => 'ro', isa => Path,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_ctrldir';

has 'dbasedir'        => is => 'ro', isa => Path,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_dbasedir';

has 'localedir'       => is => 'ro', isa => Directory, coerce => TRUE,
   lazy               => TRUE,   builder => '_build_localedir';

has 'logfile'         => is => 'ro', isa => Path,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_logfile';

has 'logsdir'         => is => 'ro', isa => Directory, coerce => TRUE,
   lazy               => TRUE,   builder => '_build_logsdir';

has 'root'            => is => 'ro', isa => Path,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_root';

has 'rundir'          => is => 'ro', isa => Path,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_rundir';

has 'sessdir'         => is => 'ro', isa => Path,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_sessdir';

has 'shell'           => is => 'ro', isa => File,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_shell';

has 'suid'            => is => 'ro', isa => Path,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_suid';

has 'tempdir'         => is => 'ro', isa => Directory, coerce => TRUE,
   lazy               => TRUE,   builder => '_build_tempdir';

has 'vardir'          => is => 'ro', isa => Path,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_vardir';


has 'name'            => is => 'ro', isa => NonEmptySimpleStr,
   lazy               => TRUE,   builder => '_build_name';

has 'owner'           => is => 'ro', isa => NonEmptySimpleStr,
   lazy               => TRUE,   builder => '_build_owner';

has 'phase'           => is => 'ro', isa => PositiveInt,
   lazy               => TRUE,   builder => '_build_phase';

has 'prefix'          => is => 'ro', isa => NonEmptySimpleStr,
   lazy               => TRUE,   builder => '_build_prefix';

has 'script'          => is => 'ro', isa => NonEmptySimpleStr,
   lazy               => TRUE,   builder => '_build_script';

has 'secret'          => is => 'ro', isa => NonEmptySimpleStr,
   lazy               => TRUE,   builder => '_build_secret';

around BUILDARGS => sub {
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

# Private methods

sub _build_appldir {
   my ($self, $appclass, $home) = __unpack( @_ );

   my $path = dirname( $Config{sitelibexp} );

   if ($home =~ m{ \A $path }mx) {
      $path = catdir( NUL, q(var), (class2appdir $appclass), q(default) );
   }
   else { $path = home2appl $home }

   return rel2abs( untaint_path $path );
}

sub _build_binsdir {
   my ($self, $attr) = @_;

   my $path = $self->_inflate_path( $attr, qw(appldir bin) );

   return -d $path ? $path : untaint_path $Config{installsitescript};
}

sub _build_ctlfile {
   my ($self, $attr) = @_; my $file = $self->name.$self->extension;

   return $self->_inflate_path( $attr, q(ctrldir), $file );
}

sub _build_ctrldir {
   return $_[ 0 ]->_inflate_path( $_[ 1 ], qw(vardir etc) );
}

sub _build_dbasedir {
   return $_[ 0 ]->_inflate_path( $_[ 1 ], qw(vardir db) );
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

   my $path = $self->_inflate_path( $attr, qw(vardir logs) );

   return -d $path ? $path : $self->_inflate_path( $attr, qw(tempdir) );
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

   my $appldir = blessed $self ? $self->appldir : $attr->{appldir};
   my $verdir  = basename( $appldir );
   my ($phase) = $verdir =~ m{ \A v \d+ \. \d+ p (\d+) \z }msx;

   return defined $phase ? $phase : PHASE;
}

sub _build_prefix {
   return (split m{ :: }mx, lc $_[ 0 ]->appclass)[ -1 ];
}

sub _build_root {
   return $_[ 0 ]->_inflate_path( $_[ 1 ], qw(vardir root) );
}

sub _build_rundir {
   return $_[ 0 ]->_inflate_path( $_[ 1 ], qw(vardir run) );
}

sub _build_script {
   return basename( $_[ 0 ]->pathname );
}

sub _build_secret {
   return $_[ 0 ]->prefix;
}

sub _build_sessdir {
   return $_[ 0 ]->_inflate_path( $_[ 1 ], qw(vardir hist) );
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
   my $path = $_[ 0 ]->_inflate_path( $_[ 1 ], qw(vardir tmp) );

   return -d $path ? $path : untaint_path tmpdir;
}

sub _build_vardir {
   my ($self, $attr) = @_;

   my $path = $self->_inflate_path( $attr, qw(appldir var) );

   return -d $path ? $path : catdir( NUL, q(var) );
}

sub _inflate_path {
   my ($self, $attr, $symbol, $relpath) = @_; $attr ||= {}; $relpath ||= NUL;

   my $base  = $self->_inflate_symbol( $attr, $symbol );

   my @parts = ($base, split m{ / }mx, $relpath);

   my $path  = catdir( @parts ); -d $path or $path = catfile( @parts );

   return untaint_path canonpath( $path );
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

no Moose;

1;

__END__

=pod

=head1 Name

Class::Usul::Config - Inflate config values

=head1 Version

Describes Class::Usul::Config version 0.1.$Revision$

=head1 Synopsis

=head1 Description

Defines the following list of attributes

=over 3

=item appclass

Required string. The classname of the application for which this is the
configuration class

=item doc_title

String defaults to 'User Contributed Documentation'. Used in the Unix man
pages

=item encoding

String default to the constant I<DEFAULT_ENCODING>

=item extension

String defaults to the constant I<CONFIG_EXTN>

=item home

Directory containing the config file. Required

=item l10n_attributes

Hash ref of attributes used to construct a L<Class::Usul::L10N> object

=item lock_attributes

Hash ref of attributes used to construct an L<IPC::SRLock> object

=item log_attributes

Hash ref of attributes used to construct a L<Class::Usul::Log> object

=item man_page_cmd

Array ref containing the command and options to produce a man page. Defaults
to I<man -nroff>

=item mode

Integer defaults to the constant I<PERMS>. The default file creation mask

=item no_thrash

Interger default to 3. Number of seconds to sleep in a polling loop to
avoid processor thrash

=item pathname

File defaults to the absolute path to the I<PROGRAM_NAME> system constant

=item appldir

Directory. Defaults to the application's install directory

=item binsdir

Directory. Defaults to the application's I<bin> directory

=item ctlfile

File in the I<ctrldir> directory that contains this programs control data

=item ctrldir

Directory containing the per program configuration files

=item dbasedir

Directory containing the data file used to create the applications database

=item localedir

Directory containing the GNU Gettext portable object files used to translate
messages into different languages

=item logfile

File in the I<logsdir> to which this program will log

=item logsdir

Directory containg the application log files

=item root

Directory. Path to the web applications document root

=item rundir

Directory. Contains a running programs PID file

=item sessdir

Directory. The session directory

=item shell

File. The default shell used to create new OS users

=item suid

File. Name of the setuid root program in the I<bin> directory. Defaults to
the I<prefix>_admin

=item tempdir

Directory. It is the location of any temporary files created by the
application. Defaults to the L<File::Spec> tempdir

=item vardir

Directory. Contains all of the non program code directories

=item name

String. Name of the program

=item owner

String. Name of the application file owner

=item phase

Integer. Phase number indicates the type of install, e.g. 1 live, 2 test,
3 development

=item prefix

String. Program prefix

=item script

String. The basename of the I<pathname> attribute

=item secret

String. This applications secret key as set by the administrators . It
is used to perturb the encryption methods. Defaults to the I<prefix>
attribute value

=back

=head1 Subroutines/Methods

=head2 BUILDARGS

Loads the configuration files if specified. Calls L</inflate_symbol>
and L</inflate_path>

=head2 _inflate_path

Infates the I<__symbol( relative_path )__> values to their actual runtime
values

=head2 _inflate_symbol

Inflates the I<__SYMBOL__> values to their actual runtime values

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

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
