# @(#)$Id$

package Class::Usul::Config;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use English qw(-no_match_vars);
use File::DataClass::Schema;
use Class::Usul::Constants;
use Sys::Hostname ();
use File::Spec;
use Config;
use Moose;

extends qw(Class::Usul);
with    qw(File::DataClass::Constraints);

has 'aliases_path'  => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE, coerce    => TRUE;

has 'appclass'      => is => 'ro', isa => 'Maybe[ClassName]',
   required         => TRUE;

has 'appldir'       => is => 'ro', isa => 'F_DC_Directory',
   lazy_build       => TRUE, coerce    => TRUE;

has 'binsdir'       => is => 'ro', isa => 'F_DC_Path',
   lazy_build       => TRUE, coerce    => TRUE;

has 'ctlfile'       => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE, coerce    => TRUE;

has 'ctrldir'       => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE, coerce    => TRUE;

has 'dbasedir'      => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE, coerce    => TRUE;

has 'home'          => is => 'ro', isa => 'F_DC_Directory',
   required         => TRUE, coerce    => TRUE;

has 'hostname'      => is => 'ro', isa => 'Str',
   lazy_build       => TRUE;

has 'logfile'       => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE, coerce    => TRUE;

has 'logsdir'       => is => 'rw', isa => 'F_DC_Directory',
   lazy_build       => TRUE, coerce    => TRUE;

has 'name'          => is => 'ro', isa => 'Str',
   required         => TRUE;

has 'no_thrash'     => is => 'rw', isa => 'Int',
   default          => 3;

has 'owner'         => is => 'rw', isa => 'Str',
   lazy_build       => TRUE;

has 'pathname'      => is => 'rw', isa => 'F_DC_File',
   lazy_build       => TRUE, coerce    => TRUE;

has 'phase'         => is => 'ro', isa => 'Int',
   lazy_build       => TRUE;

has 'prefix'        => is => 'rw', isa => 'Str',
   lazy_build       => TRUE;

has 'profiles_path' => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE, coerce    => TRUE;

has 'pwidth'        => is => 'rw', isa => 'Int',
   default          => 60;

has 'root'          => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE, coerce    => TRUE;

has 'rundir'        => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE, coerce    => TRUE;

has 'secret'        => is => 'ro', isa => 'Str',
   lazy_build       => TRUE;

has 'shell'         => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE, coerce    => TRUE;

has 'suid'          => is => 'ro', isa => 'F_DC_Path',
   lazy_build       => TRUE, coerce    => TRUE;

has 'tempdir'       => is => 'rw', isa => 'F_DC_Directory',
   lazy_build       => TRUE, coerce    => TRUE;

has 'vardir'        => is => 'rw', isa => 'F_DC_Path',
   lazy_build       => TRUE, coerce    => TRUE;

around BUILDARGS => sub {
   my ($orig, $class, @args) = @_;

   my $attrs  = $class->$orig( @args );
   my $file   = $class->app_prefix( $attrs->{appclass} ).q(.xml);
   my $path   = $class->catfile( $attrs->{home}, $file );

   -f $path or return $attrs;

   my $config = File::DataClass::Schema->new->load( $path );

   return { %{ $attrs }, %{ $config || {} } };
};

sub BUILD {
   my $self = shift;

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

   $path = $self->catdir( @parts );
   -d $path or $path = $self->catfile( @parts );

   return $self->canonpath( $path );
}

# Private methods

sub _build_aliases_path {
   return shift->inflate( qw(ctrldir aliases) );
}

sub _build_appldir {
   my $self = shift; my $path = $self->dirname( $Config{sitelibexp} );

   if ($self->home =~ m{ \A $path }mx) {
      $path = $self->class2appdir( $self->appclass );
      $path = $self->catdir( NUL, qw(var www), $path, q(default) );
   }
   else { $path = $self->home2appl( $self->home ) }

   return $self->rel2abs( $self->untaint_path( $path ) );
}

sub _build_binsdir {
   my $self = shift; my $path = $self->dirname( $Config{sitelibexp} );

   if ($self->home =~ m{ \A $path }mx) { $path = $Config{scriptdir} }
   else { $path = $self->catdir( $self->home2appl( $self->home ), q(bin) ) }

   return $self->rel2abs( $self->untaint_path( $path ) );
}

sub _build_ctlfile {
   my $self = shift;
   my $path = $self->inflate( q(ctrldir), $self->name.q(.xml) );

   return $self->untaint_path( $path );
}

sub _build_ctrldir {
   return shift->inflate( qw(vardir etc) );
}

sub _build_dbasedir {
   return shift->inflate( qw(vardir db) );
}

sub _build_hostname {
   return Sys::Hostname::hostname();
}

sub _build_logfile {
   my $self = shift;
   my $path = $self->inflate( q(logsdir), $self->name.q(.log) );

   return $self->untaint_path( $path );
}

sub _build_logsdir {
   my $self = shift;
   my $path = $self->inflate( qw(vardir logs) );

   return -d $path ? $path : $self->tempdir;
}

sub _build_owner {
   return shift->prefix || q(root);
}

sub _build_pathname {
   return shift->rel2abs( $PROGRAM_NAME );
}

sub _build_prefix {
   my $self = shift; return (split m{ :: }mx, lc $self->appclass)[-1];
}

sub _build_phase {
   my $self    = shift;
   my $dir     = $self->basename( $self->appldir );
   my ($phase) = $dir =~ m{ \A v \d+ \. \d+ p (\d+) \z }msx;

   return defined $phase ? $phase : PHASE;
}

sub _build_profiles_path {
   return shift->inflate( qw(ctrldir user_profiles.xml) );
}

sub _build_root {
   return shift->inflate( qw(vardir root) );
}

sub _build_rundir {
   return shift->inflate( qw(vardir run) );
}

sub _build_secret {
   return shift->prefix;
}

sub _build_shell {
   return shift->catfile( NUL, qw(bin ksh) );
}

sub _build_suid {
   my $self = shift;

   return $self->inflate( q(binsdir), $self->prefix.q(_admin) );
}

sub _build_tempdir {
   my $self = shift;
   my $path = $self->inflate( qw(vardir tmp) );

   return -d $path ? $path : $self->untaint_path( File::Spec->tmpdir );
}

sub _build_vardir {
   return shift->inflate( qw(appldir var) );
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
