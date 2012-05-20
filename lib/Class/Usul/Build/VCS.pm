# @(#)$Id: Build.pm 818 2010-01-11 18:32:22Z pjf $

package Class::Usul::Build::VCS;

use strict;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 818 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use File::Spec;
use IPC::Cmd qw(can_run);

has 'type' => is => 'rw', isa => 'Str';
has 'vcs'  => is => 'rw', isa => 'Object';

around BUILDARGS => sub {
   my ($next, $class, @rest) = @_; my $attrs = $class->$next( @rest );

   my $dir = $attrs->{project_dir};

   if (-d File::Spec->catfile( $dir, q(.git) )) {
      can_run( q(git) ) or return $attrs; # Be nice to CPAN testing

      require Git::Class::Worktree;

      $attrs->{vcs } = Git::Class::Worktree->new( path => $dir );
      $attrs->{type} = q(git);
      return $attrs;
   }

   $dir = File::Spec->catfile( $attrs->{project_dir}, q(.svn) );

   if (-d $dir) {
      can_run( q(svn) ) or return $attrs; # Be nice to CPAN testing

      require SVN::Class;

      $attrs->{vcs } = SVN::Class::svn_dir( $dir );
      $attrs->{type} = q(svn);
      return $attrs;
   }

   return $attrs;
};

sub commit {
   my ($self, $msg) = @_;

   $self->type eq q(git)
      and return $self->vcs->commit( { all => TRUE, message => $msg } );

   return $self->vcs->commit( $msg );
}

sub error {
   # TODO: Git implementation
   my $self = shift; return $self->vcs ? $self->vcs->error : 'No VCS';
}

sub repository {
   # TODO: Git implementation
   my $self = shift; $self->vcs or return;

   my $info = $self->vcs->info or return;

   return $info->root;
}

sub tag {
   my ($self, $tag) = @_; my $vtag = q(v).$tag; $self->vcs or return;

   $self->type eq q(git) and return $self->vcs->tag( { tag => $vtag } );

   my $repo = $self->repository or return;
   my $from = $repo.SEP.q(trunk);
   my $to   = $repo.SEP.q(tags).SEP.$vtag;
   my $msg  = "Tagging ${vtag}";

   return $self->vcs->svn_run( q(copy), [ q(-m), $msg ], "${from} ${to}" );
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

Class::Usul::Build::VCS - Version control system

=head1 Version

This document describes Class::Usul::Build::VCS version 0.1.$Revision: 818 $

=head1 Synopsis

   use Class::Usul::Build::VCS;

   $vcs_object = Class::Usul::Build::VCS->new;

=head1 Description

Proxies methods for either L<SVN::Class> or L<Git::Class::Worktree>
depending on which is being used by the application

=head1 Subroutines/Methods

=head2 commit

   $result = $self->commit( $message );

Commits all outstanding updates with the supplied message

=head2 error

   $error = $self->error;

Returns the last VCS error

=head2 repository

   $uri = $self->repository;

Returns the URI of the VCS repository

=head2 tag

   $self->tag( $tag )

Creates a tagged copy of trunk

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Git::Class::Worktree>

=item L<IPC::Cmd>

=item L<SVN::Class>

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
