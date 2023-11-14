package Class::Usul::TraitFor::IPC;

use Class::Usul::Types qw( DataLumper LoadableClass ProcCommer );
use Moo::Role;

requires qw( run_cmd );

has 'file' =>
   is      => 'lazy',
   isa     => DataLumper,
   default => sub { $_[0]->_ipc_file_class->new(builder => $_[0]) };

has '_ipc_file_class' =>
   is      => 'lazy',
   isa     => LoadableClass,
   default => 'Class::Usul::File';

has 'ipc' =>
   is      => 'lazy',
   isa     => ProcCommer,
   default => sub { $_[0]->_ipc_process_class->new(builder => $_[0]) };

has '_ipc_process_class' =>
   is      => 'lazy',
   isa     => LoadableClass,
   default => 'Class::Usul::IPC';

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Class::Usul::TraitFor::IPC - File and IPC

=head1 Synopsis

   use Moo;

   extends 'Class::Usul::Programs';
   with 'Class::Usul::TraitFor::IPC';

=head1 Description

File and IPC

=head1 Configuration and Environment

Defines the following public attributes;

=over 3

=item C<file>

An instance of L<Class::Usul::File>

=item C<ipc>

An instance of L<Class::Usul::IPC>

=back

=head1 Subroutines/Methods

Defines no public methods

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::File>

=item L<Class::Usul::IPC>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.  Please report problems to the address
below.  Patches are welcome

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2023 Peter Flanigan. All rights reserved

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
