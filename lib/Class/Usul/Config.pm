# @(#)$Id$

package Class::Usul::Config;

use strict;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions       qw(app_prefix class2appdir
                                    home2appl untaint_path);
use Config;
use English                      qw(-no_match_vars);
use File::Basename               qw(basename dirname);
use File::DataClass::Constraints qw(Directory File Path);
use File::Gettext::Constants;
use File::Spec::Functions        qw(canonpath catdir catfile rel2abs tmpdir);
use Sys::Hostname                  ();

has 'appclass'        => is => 'ro', isa => Str,
   required           => TRUE;

has 'doc_title'       => is => 'ro', isa => Str,
   default            => 'User Contributed Documentation';

has 'encoding'        => is => 'ro', isa => Str,
   default            => DEFAULT_ENCODING;

has 'extension'       => is => 'ro', isa => Str,
   default            => CONFIG_EXTN;

has 'home'            => is => 'ro', isa => Directory, coerce => TRUE,
   documentation      => 'Directory containing the config file',
   required           => TRUE;

has 'hostname'        => is => 'ro', isa => Str,
   default            => sub { Sys::Hostname::hostname() };

has 'l10n_attributes' => is => 'ro', isa => HashRef,
   default            => sub { {} };

has 'lock_attributes' => is => 'ro', isa => HashRef,
   default            => sub { {} };

has 'log_attributes'  => is => 'ro', isa => HashRef,
   default            => sub { {} };

has 'man_page_cmd'    => is => 'ro', isa => ArrayRef,
   default            => sub { [ qw(nroff -man) ] };

has 'mode'            => is => 'ro', isa => Int,
   default            => PERMS;

has 'no_thrash'       => is => 'ro', isa => Int,
   default            => 3;

has 'pathname'        => is => 'ro', isa => File, coerce => TRUE,
   default            => sub { rel2abs( $PROGRAM_NAME ) };


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

has 'shell'           => is => 'ro', isa => File,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_shell';

has 'suid'            => is => 'ro', isa => Path,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_suid';

has 'tempdir'         => is => 'ro', isa => Directory, coerce => TRUE,
   lazy               => TRUE,   builder => '_build_tempdir';

has 'vardir'          => is => 'ro', isa => Path,      coerce => TRUE,
   lazy               => TRUE,   builder => '_build_vardir';


has 'name'            => is => 'ro', isa => Str,
   lazy               => TRUE,   builder => '_build_name';

has 'owner'           => is => 'ro', isa => Str,
   lazy               => TRUE,   builder => '_build_owner';

has 'phase'           => is => 'ro', isa => Int,
   lazy               => TRUE,   builder => '_build_phase';

has 'prefix'          => is => 'ro', isa => Str,
   lazy               => TRUE,   builder => '_build_prefix';

has 'script'          => is => 'ro', isa => Str,
   lazy               => TRUE,   builder => '_build_script';

has 'secret'          => is => 'ro', isa => Str,
   lazy               => TRUE,   builder => '_build_secret';

# TODO: Move these away, a long way away
has 'aliases_path'    => is => 'ro', isa => Path, coerce => TRUE,
   lazy               => TRUE,   builder => '_build_aliases_path';

has 'profiles_path'   => is => 'ro', isa => Path, coerce => TRUE,
   lazy               => TRUE,   builder => '_build_profiles_path';

around BUILDARGS => sub {
   my ($next, $class, @args) = @_; my $attrs = $class->$next( @args );

   for my $k (keys %{ $attrs }) {
      defined $attrs->{ $k }
         and $attrs->{ $k } =~ m{ \A __([^\(]+?)__ \z }mx
         and $attrs->{ $k } = $class->_inflate( $attrs, $1, NUL );
   }

   for my $k (keys %{ $attrs }) {
      defined $attrs->{ $k }
         and $attrs->{ $k } =~ m{ \A __(.+?)\((.+?)\)__ \z }mx
         and $attrs->{ $k } = $class->_inflate( $attrs, $1, $2 );
   }

   return $attrs;
};

# Private methods

sub _build_appldir {
   my ($self, $appclass, $home) = __unpack( @_ );

   my $path = dirname( $Config{sitelibexp} );

   if ($home =~ m{ \A $path }mx) {
      $path = class2appdir $appclass;
      $path = catdir( NUL, qw(var www), $path, q(default) );
   }
   else { $path = home2appl $home }

   return rel2abs( untaint_path $path );
}

sub _build_binsdir {
   my ($self, $appclass, $home) = __unpack( @_ );

   my $path = dirname( $Config{sitelibexp} );

   if ($home =~ m{ \A $path }mx) { $path = $Config{scriptdir} }
   else { $path = catdir( home2appl $home, q(bin) ) }

   return rel2abs( untaint_path $path );
}

sub _build_ctlfile {
   my ($self, $attrs) = @_;

   return $self->_inflate( $attrs, q(ctrldir), $self->name.$self->extension );
}

sub _build_ctrldir {
   return $_[ 0 ]->_inflate( $_[ 1 ], qw(vardir etc) );
}

sub _build_dbasedir {
   return $_[ 0 ]->_inflate( $_[ 1 ], qw(vardir db) );
}

sub _build_localedir {
   my ($self, $attrs) = @_; my $dir;

   $dir = $self->_inflate( $attrs, qw(vardir locale) ); -d $dir and return $dir;

   for (map { catdir( @{ $_ } ) } @{ DIRECTORIES() } ) { -d $_ and return $_ }

   return $self->_inflate( $attrs, qw(tempdir) );
}

sub _build_logfile {
   return $_[ 0 ]->_inflate( $_[ 1 ], q(logsdir), $_[ 0 ]->name.q(.log) );
}

sub _build_logsdir {
   my $path = $_[ 0 ]->_inflate( $_[ 1 ], qw(vardir logs) );

   return -d $path ? $path : $_[ 0 ]->tempdir;
}

sub _build_name {
   return basename( $_[ 0 ]->pathname, EXTNS );
}

sub _build_owner {
   return $_[ 0 ]->prefix || q(root);
}

sub _build_path_to {
   my ($self, $appclass, $home) = __unpack( @_ ); return $home;
}

sub _build_phase {
   my $dir     = basename( $_[ 0 ]->appldir );
   my ($phase) = $dir =~ m{ \A v \d+ \. \d+ p (\d+) \z }msx;

   return defined $phase ? $phase : PHASE;
}

sub _build_prefix {
   return (split m{ :: }mx, lc $_[ 0 ]->appclass)[ -1 ];
}

sub _build_root {
   return $_[ 0 ]->_inflate( $_[ 1 ], qw(vardir root) );
}

sub _build_rundir {
   return $_[ 0 ]->_inflate( $_[ 1 ], qw(vardir run) );
}

sub _build_script {
   return basename( $_[ 0 ]->pathname );
}

sub _build_secret {
   return $_[ 0 ]->prefix;
}

sub _build_shell {
   my $file = catfile( NUL, qw(bin ksh) ); -f $file and return $file;

   $file = $ENV{SHELL}; -f $file and return $file;

   return catfile( NUL, qw(bin sh) );
}

sub _build_suid {
   return $_[ 0 ]->_inflate( $_[ 1 ], q(binsdir), $_[ 0 ]->prefix.q(_admin) );
}

sub _build_tempdir {
   my $path = $_[ 0 ]->_inflate( $_[ 1 ], qw(vardir tmp) );

   return -d $path ? $path : untaint_path tmpdir;
}

sub _build_vardir {
   return $_[ 0 ]->_inflate( $_[ 1 ], qw(appldir var) );
}

sub _build_aliases_path {
   return $_[ 0 ]->_inflate( $_[ 1 ], qw(ctrldir aliases) );
}

sub _build_profiles_path {
   return $_[ 0 ]->_inflate( $_[ 1 ], q(ctrldir),
                             q(user_profiles).$_[ 0 ]->extension );
}

sub _inflate {
   my ($self, $attrs, $symbol, $relpath) = @_; $attrs ||= {}; $relpath ||= NUL;

   my $k     = lc $symbol; my $method = q(_build_).$k;

   my $base  = defined $attrs->{ $k } && $attrs->{ $k } !~ m{ \A __ }mx
             ? $attrs->{ $k } : $self->$method( $attrs );

   my @parts = ($base, split m{ / }mx, $relpath);

   my $path  = catdir( @parts ); -d $path or $path = catfile( @parts );

   return untaint_path canonpath( $path );
}

# Private functions

sub __unpack {
   my ($self, $attrs) = @_; $attrs ||= {};

   blessed $self and return ($self, $self->appclass, $self->home);

   return ($self, $attrs->{appclass}, $attrs->{home});
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

=over 3

=item secret

This applications secret key as set by the administrators in the
configuration. It is used to perturb the encryption methods. Defaults to
the I<prefix> attribute value

=item suid

Name of the setuid root program in the I<bin> directory. Defaults to
the I<prefix>_admin

=item tempdir

Supplied by the config hash, it is the location of any temporary files
created by the application. Defaults to the L<File::Spec> tempdir

=back

=head1 Subroutines/Methods

=head2 BUILDARGS

=head2 BUILD

=head2 inflate

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
