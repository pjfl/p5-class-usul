# @(#)$Id$

package Class::Usul::Config;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use Class::Usul::Constants;
use File::Gettext::Constants;
use Class::Usul::Functions qw(app_prefix class2appdir home2appl untaint_path);
use File::Spec::Functions  qw(canonpath catdir catfile rel2abs tmpdir);
use File::Basename         qw(basename dirname);
use English                qw(-no_match_vars);
use Sys::Hostname            ();
use Config;

with qw(File::DataClass::Constraints);

has 'appclass'      => is => 'ro', isa => 'Str',
   required         => TRUE;

has 'appldir'       => is => 'ro', isa => 'F_DC_Directory',
   lazy_build       => TRUE,    coerce => TRUE;

has 'binsdir'       => is => 'ro', isa => 'F_DC_Path',
   lazy_build       => TRUE,    coerce => TRUE;

has 'ctlfile'       => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE,    coerce => TRUE;

has 'ctrldir'       => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE,    coerce => TRUE;

has 'dbasedir'      => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE,    coerce => TRUE;

has 'doc_title'     => is => 'ro', isa => 'Str',
   default          => 'User Contributed Documentation';

has 'extension'     => is => 'ro', isa => 'Str',
   default          => CONFIG_EXTN;

has 'home'          => is => 'ro', isa => 'F_DC_Directory',
   documentation    => 'Directory containing the config file',
   required         => TRUE,    coerce => TRUE;

has 'hostname'      => is => 'ro', isa => 'Str',
   lazy_build       => TRUE;

has 'localedir'     => is => 'ro', isa => 'F_DC_Directory',
   default          => sub { DIRECTORIES->[ 0 ] }, coerce => TRUE;

has 'logfile'       => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE,    coerce => TRUE;

has 'logsdir'       => is => 'rw', isa => 'F_DC_Directory',
   lazy_build       => TRUE,    coerce => TRUE;

has 'man_page_cmd'  => is => 'ro', isa => 'ArrayRef',
   default          => sub { [ qw(nroff -man) ] };

has 'mode'          => is => 'rw', isa  => 'Int',
   default          => PERMS;

has 'name'          => is => 'ro', isa => 'Str',
   lazy_build       => TRUE;

has 'no_thrash'     => is => 'rw', isa => 'Int',
   default          => 3;

has 'owner'         => is => 'rw', isa => 'Str',
   lazy_build       => TRUE;

has 'pathname'      => is => 'rw', isa => 'F_DC_File',
   lazy_build       => TRUE,    coerce => TRUE;

has 'phase'         => is => 'ro', isa => 'Int',
   lazy_build       => TRUE;

has 'prefix'        => is => 'rw', isa => 'Str',
   lazy_build       => TRUE;

has 'pwidth'        => is => 'rw', isa => 'Int',
   default          => 60;

has 'root'          => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE,    coerce => TRUE;

has 'rundir'        => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE,    coerce => TRUE;

has 'script'        => is => 'ro', isa => 'Str',
   lazy_build       => TRUE;

has 'secret'        => is => 'ro', isa => 'Str',
   lazy_build       => TRUE;

has 'shell'         => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE,    coerce => TRUE;

has 'suid'          => is => 'ro', isa => 'F_DC_Path',
   lazy_build       => TRUE,    coerce => TRUE;

has 'tempdir'       => is => 'rw', isa => 'F_DC_Directory',
   lazy_build       => TRUE,    coerce => TRUE;

has 'vardir'        => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE,    coerce => TRUE;

# TODO: Move these away, a long way away
has 'aliases_path'  => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE,    coerce => TRUE;

has 'profiles_path' => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE,    coerce => TRUE;

sub BUILD {
   my $self = shift;

   for my $k ($self->meta->get_attribute_list) {
      my $v = $self->$k();

      if ($v =~ m{ __([^\(]+?)__ }mx) {
         $v =~ s{ __(.+?)__ }{$self->inflate( $1, NUL )}egmx;
         $self->$k( $v );
      }
   }

   for my $k ($self->meta->get_attribute_list) {
      my $v = $self->$k();

      if ($v =~ m{ __(.+?)\((.+?)\)__ }mx) {
         $v =~ s{ __(.+?)\((.+?)\)__ }{$self->inflate( $1, $2 )}egmx;
         $self->$k( $v );
      }
   }

   return;
}

sub inflate {
   my ($self, $symbol, $path) = @_; my $method = lc $symbol;

   $method eq q(path_to) and $method = q(home);

   my @parts = ($self->$method(), split m{ / }mx, $path);

   $path = catdir( @parts ); -d $path or $path = catfile( @parts );

   return untaint_path canonpath( $path );
}

# Private methods

sub _build_appldir {
   my $self = shift; my $path = dirname( $Config{sitelibexp} );

   if ($self->home =~ m{ \A $path }mx) {
      $path = class2appdir $self->appclass;
      $path = catdir( NUL, qw(var www), $path, q(default) );
   }
   else { $path = home2appl $self->home }

   return rel2abs( untaint_path $path );
}

sub _build_binsdir {
   my $self = shift; my $path = dirname( $Config{sitelibexp} );

   if ($self->home =~ m{ \A $path }mx) { $path = $Config{scriptdir} }
   else { $path = catdir( home2appl $self->home, q(bin) ) }

   return rel2abs( untaint_path $path );
}

sub _build_ctlfile {
   return $_[ 0 ]->inflate( q(ctrldir), $_[ 0 ]->name.$_[ 0 ]->extension );
}

sub _build_ctrldir {
   return $_[ 0 ]->inflate( qw(vardir etc) );
}

sub _build_dbasedir {
   return $_[ 0 ]->inflate( qw(vardir db) );
}

sub _build_hostname {
   return Sys::Hostname::hostname();
}

sub _build_localedir {
   return $_[ 0 ]->inflate( qw(vardir locale) );
}

sub _build_logfile {
   return $_[ 0 ]->inflate( q(logsdir), $_[ 0 ]->name.q(.log) );
}

sub _build_logsdir {
   my $path = $_[ 0 ]->inflate( qw(vardir logs) );

   return -d $path ? $path : $_[ 0 ]->tempdir;
}

sub _build_name {
   return basename( $_[ 0 ]->pathname, EXTNS );
}

sub _build_owner {
   return $_[ 0 ]->prefix || q(root);
}

sub _build_pathname {
   return rel2abs( $PROGRAM_NAME );
}

sub _build_prefix {
   return (split m{ :: }mx, lc $_[ 0 ]->appclass)[ -1 ];
}

sub _build_phase {
   my $dir     = basename( $_[ 0 ]->appldir );
   my ($phase) = $dir =~ m{ \A v \d+ \. \d+ p (\d+) \z }msx;

   return defined $phase ? $phase : PHASE;
}

sub _build_root {
   return $_[ 0 ]->inflate( qw(vardir root) );
}

sub _build_rundir {
   return $_[ 0 ]->inflate( qw(vardir run) );
}

sub _build_script {
   return basename( $_[ 0 ]->pathname );
}

sub _build_secret {
   return $_[ 0 ]->prefix;
}

sub _build_shell {
   return catfile( NUL, qw(bin ksh) );
}

sub _build_suid {
   return $_[ 0 ]->inflate( q(binsdir), $_[ 0 ]->prefix.q(_admin) );
}

sub _build_tempdir {
   my $path = $_[ 0 ]->inflate( qw(vardir tmp) );

   return -d $path ? $path : untaint_path tmpdir;
}

sub _build_vardir {
   return $_[ 0 ]->inflate( qw(appldir var) );
}

sub _build_aliases_path {
   return $_[ 0 ]->inflate( qw(ctrldir aliases) );
}

sub _build_profiles_path {
   return $_[ 0 ]->inflate( q(ctrldir), q(user_profiles).$_[ 0 ]->extension );
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
