# @(#)$Id$

package Class::Usul::InflateSymbols;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Constants;
use Cwd qw(abs_path);
use File::Spec;
use Config;
use Moose;

extends qw(Class::Usul);

has 'args' => is => 'ro', isa => 'HashRef', default => sub { {} };

sub inflate {
   my $self = shift;

   $self->$_() for (grep { $_ ne q(inflate)
                           and $_ ne q(new) and $_ ne q(DESTROY) }
                    $self->meta->get_method_list);

   return;
}

sub appldir {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{appldir} or $conf->{appldir} =~ m{ __APPLDIR__ }mx) {
      my $v = $self->dirname( $Config{sitelibexp} );

      if ($args->{home} =~ m{ \A $v }mx) {
         $v = $self->class2appdir( $args->{name} );
         $v = $self->catdir( NUL, qw(var www), $v, q(default) );
      }
      else { $v = $self->home2appl( $args->{home} ) }

      $conf->{appldir} = abs_path( $self->untaint_path( $v ) );
   }

   return $conf->{appldir};
}

sub binsdir {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{binsdir} or $conf->{binsdir} =~ m{ __BINSDIR__ }mx) {
      my $v = $self->dirname( $Config{sitelibexp} );

      if ($args->{home} =~ m{ \A $v }mx) { $v = $Config{scriptdir} }
      else { $v = $self->catdir( $self->home2appl( $args->{home} ), q(bin) ) }

      $conf->{binsdir} = abs_path( $self->untaint_path( $v ) );
   }

   return $conf->{binsdir};
}

sub ctlfile {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{ctlfile} or $conf->{ctlfile} =~ m{ __CTLFILE__ }mx) {
      my $path = $self->catdir( $self->ctrldir, $args->{name}.q(.xml) );

      $conf->{ctlfile} = $self->untaint_path( $path );
   }

   return $conf->{ctlfile};
}

sub ctrldir {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{ctrldir} or $conf->{ctrldir} =~ m{ __CTRLDIR__ }mx) {
      $conf->{ctrldir} = $self->catdir( $self->vardir, q(etc) );
   }

   return $conf->{ctrldir};
}

sub dbasedir {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{dbasedir} or $conf->{dbasedir} =~ m{ __DBASEDIR__ }mx) {
      $conf->{dbasedir} = $self->catdir( $self->vardir, q(db) );
   }

   return $conf->{dbasedir};
}

sub logfile {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{logfile} or $conf->{logfile} =~ m{ __LOGFILE__ }mx) {
      my $path = $self->catdir( $self->logsdir, $args->{name}.q(.log) );

      $conf->{logfile} = $self->untaint_path( $path );
   }

   return $conf->{logfile};
}

sub logsdir {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{logsdir} or $conf->{logsdir} =~ m{ __LOGSDIR__ }mx) {
      $conf->{logsdir} = $self->catdir( $self->vardir, q(logs) );
      -d $conf->{logsdir} or $conf->{logsdir} = $self->tempdir;
   }

   return $conf->{logsdir};
}

sub path_to {
   return shift->args->{home};
}

sub pathname {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{pathname} or $conf->{pathname} =~ m{ __PATHNAME__ }mx) {
      $conf->{pathname} = $self->catfile( $self->binsdir, $args->{script} );
   }

   return $conf->{pathname};
}

sub phase {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{phase} or $conf->{phase} =~ m{ __PHASE__ }mx) {
      my $dir     = $self->basename( $self->appldir );
      my ($phase) = $dir =~ m{ \A v \d+ \. \d+ p (\d+) \z }msx;

      $conf->{phase} = defined $phase ? $phase : PHASE;
   }

   return $conf->{phase};
}

sub root {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{root} or $conf->{root} =~ m{ __ROOT__ }mx) {
      $conf->{root} = $self->catdir( $self->vardir, q(root) );
   }

   return $conf->{root};
}

sub rundir {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{rundir} or $conf->{rundir} =~ m{ __RUNDIR__ }mx) {
      $conf->{rundir} = $self->catdir( $self->vardir, q(run) );
   }

   return $conf->{rundir};
}

sub suid {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{suid} or $conf->{suid} =~ m{ __SUID__ }mx) {
      my $file = $args->{prefix}.q(_admin);

      $conf->{suid} = $self->catfile( $self->binsdir, $file );
   }

   return $conf->{suid};
}

sub tempdir {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{tempdir} or $conf->{tempdir} =~ m{ __TEMPDIR__ }mx) {
      $conf->{tempdir} = $self->catdir( $self->vardir, q(tmp) );
      -d $conf->{tempdir}
         or $conf->{tempdir} = $self->untaint_path( File::Spec->tmpdir );
   }

   return $conf->{tempdir};
}

sub vardir {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{vardir} or $conf->{vardir} =~ m{ __VARDIR__ }mx) {
      $conf->{vardir} = $self->catdir( $self->appldir, q(var) );
   }

   return $conf->{vardir};
}

sub aliases_path {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{aliases_path}
       or  $conf->{aliases_path} =~ m{ __ALIASES_PATH__ }mx) {
      my $path = $self->catdir( $self->ctrldir, q(aliases) );

      $conf->{aliases_path} = $self->untaint_path( $path );
   }

   return $conf->{aliases_path};
}

sub profiles_path {
   my $self = shift; my $args = $self->args; my $conf = $args->{config};

   if (not $conf->{profiles_path}
       or  $conf->{profiles_path} =~ m{ __PROFILES_PATH__ }mx) {
      my $path = $self->catdir( $self->ctrldir, q(user_profiles.xml) );

      $conf->{profiles_path} = $self->untaint_path( $path );
   }

   return $conf->{profiles_path};
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

Class::Usul::InflateSymbols - Inflate config values

=head1 Version

Describes Class::Usul::InflateSymbols version 0.1.$Revision$

=head1 Synopsis

=head1 Description

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
