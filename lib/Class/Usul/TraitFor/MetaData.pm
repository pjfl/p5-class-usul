package # Hide from indexer
   Class::Usul::Response::Meta;

use namespace::clean -except => 'meta';

use Moo;
use Class::Usul::Constants; # Need EXCEPTION_CLASS for PathNotFound import
use Class::Usul::File;
use Class::Usul::Functions qw( io throw );
use Class::Usul::Types     qw( ArrayRef HashRef Maybe Str );
use Unexpected::Functions  qw( PathNotFound );

has 'abstract' => is => 'ro', isa => Maybe[Str];
has 'author'   => is => 'ro', isa => Maybe[ArrayRef];
has 'license'  => is => 'ro', isa => Maybe[ArrayRef];
has 'name'     => is => 'ro', isa => Maybe[Str];
has 'provides' => is => 'ro', isa => Maybe[HashRef];
has 'version'  => is => 'ro', isa => Maybe[Str];

around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   my $file_class = 'Class::Usul::File'; my $file_name = 'META.json';

   for my $dir (@{ $attr->{directories} || [] }, io()->cwd) {
      my $file = $dir->catfile( $file_name );

      $file->exists and return $file_class->data_load( paths => [ $file ] );
   }

   throw class => PathNotFound, args => [ $file_name ], level => 3;
   return;
};

package Class::Usul::TraitFor::MetaData;

use namespace::sweep;

use Class::Usul::Functions qw( io );
use Moo::Role;

requires qw( config );

sub get_package_meta {
   my ($self, $dir) = @_; my $conf = $self->config;

   my @dirs = $dir ? (io( $dir )) : ();

   $conf->can( 'ctrldir' ) and push @dirs, $conf->ctrldir;
   $conf->can( 'appldir' ) and push @dirs, $conf->appldir;

   return Class::Usul::Response::Meta->new( directories => \@dirs );
}

1;

__END__

=pod

=head1 Name

Class::Usul::TraitFor::MetaData - Class for CPAN Meta file

=head1 Synopsis

   use Moo;

   with 'Class::Usul::TraitFor::MetaData';

   $meta_data_object_ref = $self->get_package_meta( $directory );

=head1 Description

Loads the specified JSON file and returns on object
which define accessors for it's attributes

=head1 Configuration and Environment

Defines the following attributes

=over 3

=item C<abstract>

=item C<author>

=item C<license>

=item C<name>

=item C<provides>

=item C<version>

=back

=head1 Subroutines/Methods

=head2 BUILDARGS

Monkey with the constructors signature

=head2 get_package_meta

   $response_obj = $self->get_package_meta( $dir );

Extracts; I<name>, I<version>, I<author> and I<abstract> from the
F<META.json> file.  Looks in the optional C<$dir> directory
for the file in addition to C<< $config->appldir >> and C<< $config->ctrldir >>.
Returns a response object with read-only accessors defined

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
