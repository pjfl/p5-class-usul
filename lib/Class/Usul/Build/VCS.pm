# @(#)$Id: Build.pm 818 2010-01-11 18:32:22Z pjf $

package Class::Usul::Build::VCS;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 818 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use IPC::Cmd qw(can_run);
use Moose;

with qw(Class::Usul);

has 'type' => is => 'rw', isa => 'Str';
has 'vcs'  => is => 'rw', isa => 'Object';

sub BUILDARGS {
   my ($orig, $class, $project_dir) = @_;

   my $attrs = {};

   if (-d $class->catfile( $project_dir, q(.git) )) {
      can_run( q(git) ) or return; # Be nice to CPAN testing

      require Git::Class::Worktree;

      $attrs->{vcs } = Git::Class::Worktree->new( path => $project_dir );
      $attrs->{type} = q(git);
      return $attrs;
   }

   if (-d $class->catfile( $project_dir, q(.svn) )) {
      can_run( q(svn) ) or return; # Be nice to CPAN testing

      require SVN::Class;

      $attrs->{vcs } = SVN::Class::svn_dir( $project_dir );
      $attrs->{type} = q(svn);
      return $attrs;
   }

   return {};
}

sub commit {
   my ($self, $msg) = @_;

   $self->type eq q(git)
      and return $self->vcs->commit( { all => TRUE, message => $msg } );

   return $self->vcs->commit( $msg );
}

sub error {
   my $self = shift; return $self->vcs->error;
}

sub repository {
   my $self = shift; my $info = $self->vcs->info or return; return $info->root;
}

sub tag {
   my ($self, $tag) = @_; my $vtag = q(v).$tag;

   $self->type eq q(git) and return $self->vcs->tag( { tag => $vtag } );

   my $repo = $self->repository or return;
   my $from = $repo.SEP.q(trunk);
   my $to   = $repo.SEP.q(tags).SEP.$vtag;
   my $msg  = "Tagging $vtag";

   return $self->vcs->svn_run( q(copy), [ q(-m), $msg ], "$from $to" );
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

Class::Usul::Build::VCS - Version control

=head1 Version

This document describes Class::Usul::Build::VCS version 0.1.$Revision: 818 $

=head1 Synopsis

=head1 Description

=head1 Subroutines/Methods

=head1 Diagnostics

None

=head1 Configuration and Environment

=head1 Dependencies

=over 3

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
