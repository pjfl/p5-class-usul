# @(#)$Ident: Meta.pm 2013-05-10 15:43 pjf ;

package Class::Usul::Response::Meta;

use version; our $VERSION = qv( sprintf '0.20.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::File;
use Class::Usul::Functions qw(is_arrayref throw);
use Cwd                    qw(getcwd);
use YAML::Syck;

has 'abstract' => is => 'ro', isa => 'Maybe[Str]';
has 'author'   => is => 'ro', isa => 'Maybe[ArrayRef]';
has 'license'  => is => 'ro', isa => 'Maybe[ArrayRef]';
has 'name'     => is => 'ro', isa => 'Maybe[Str]';
has 'provides' => is => 'ro', isa => 'Maybe[HashRef]';
has 'version'  => is => 'ro', isa => 'Maybe[Str]';

around 'BUILDARGS' => sub {
   my ($next, $self, @args) = @_; my $attr = $self->$next( @args );

   my $file_class = 'Class::Usul::File';

   for my $dir (@{ $attr->{directories} || [] }, $file_class->io( getcwd )) {
      my $file = $dir->catfile( 'META.json' );

      $file->exists and return $file_class->data_load( paths => [ $file ] );
      $file = $dir->catfile( 'META.yml' );

      if ($file->exists) {
         my $meta_data = LoadFile( $file->pathname ) || {};

         exists $meta_data->{license}
            and not is_arrayref $meta_data->{license}
            and $meta_data->{license} = [ $meta_data->{license} ];
         return $meta_data;
      }
   }

   throw error => 'No META.json or META.yml file', level => 5;
   return;
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

Class::Usul::Response::Meta - Class for CPAN Meta file

=head1 Version

This document describes Class::Usul::Response::Meta version v0.16.$Rev: 1 $

=head1 Synopsis

   use Class::Usul::Response::Meta;

   Class::Usul::Response::Meta->new( $path_to_meta_yaml_file );

=head1 Description

Uses L<YAML::Syck> to load the specified YAML file and returns on object
which define accessors for it's attributes

=head1 Subroutines/Methods

None

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moose>

=item L<YAML::Syck>

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

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
