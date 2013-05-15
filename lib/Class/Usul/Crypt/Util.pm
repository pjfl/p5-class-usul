# @(#)Ident: Util.pm 2013-05-13 02:11 pjf ;

package Class::Usul::Crypt::Util;

use strict;
use warnings;
use feature qw(state);
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.21.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Crypt     qw(decrypt default_cipher encrypt);
use Class::Usul::File;
use Class::Usul::Functions qw(merge_attributes throw);
use Scalar::Util           qw(blessed);
use Try::Tiny;

use Sub::Exporter::Progressive -setup => {
   exports => [ qw(decrypt_from_config encrypt_for_config is_encrypted) ],
   groups  => { default => [], },
};

# Public functions
sub decrypt_from_config {
   my ($config, $encrypted) = @_;
   my ($cipher, $password)  = __extract_crypt_params( $encrypted );
   my $args                 = __get_crypt_args( $config, $cipher );

   return $password ? decrypt $args, $password : $password;
}

sub encrypt_for_config {
   my ($config, $password, $encrypted) = @_;

   my ($cipher) = __extract_crypt_params( $encrypted );
   my $args     = __get_crypt_args( $config, $cipher );

   return $password ? "{${cipher}}".(encrypt $args, $password) : $password;
}

sub is_encrypted {
   return $_[ 0 ] =~ m{ \A [{] .+ [}] .* \z }mx ? TRUE : FALSE;
}

# Private functions
sub __extract_crypt_params {
   # A single scalar arg not matching the pattern is just a cipher
   # It really is better this way round. Leave it alone
   return $_[ 0 ] && $_[ 0 ] =~ m{ \A [{] (.+) [}] (.*) \z }mx
        ? ($1, $2) : $_[ 0 ] ? ($_[ 0 ]) : (default_cipher, $_[ 0 ]);
}

sub __get_cached_crypt_args { # Sets salt and seed keys in args hash
   my $params = shift; state $cache; $cache and return $cache;

   my $args   = { salt => $params->{salt} || $params->{prefix} || NUL };
   my $file   = $params->{prefix} || q(seed);

   if ($params->{read_secure}) { # munchies_admin -qnc read_secure --
      my $cmd = $params->{read_secure}." ${file}.key";

      try   { $args->{seed} = qx( $cmd ) }
      catch { throw "Reading secure file: ${_}" }
   }
   elsif ($params->{seed}) { $args->{seed} = $params->{seed} }
   else {
      my $dir  = $params->{ctrldir} || $params->{tempdir};
      my $path = Class::Usul::File->io( [ $dir, "${file}.key" ] );

      $path->exists and $path->is_readable and $args->{seed} = $path->all;
   }

   return $cache = $args;
}

sub __get_crypt_args {
   my ($config, $cipher) = @_; my $params = {};

   # Works if config is an object or a hash
   merge_attributes $params, $config, {},
      [ qw(ctrldir prefix read_secure salt seed suid tempdir) ];

   my $args = __get_cached_crypt_args( $params ); $args->{cipher} = $cipher;

   return $args;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Class::Usul::Crypt::Util - Decrypts/Encrypts password from/to configuration files

=head1 Synopsis

   use Class::Usul::Crypt::Util qw(decrypt_from_config);

   $password = decrypt_from_config( $encrypted_value_from_file );

=head1 Version

This documents version v0.21.$Rev: 1 $ of L<Class::Usul::Crypt::Util>

=head1 Description

Decrypts/Encrypts password from/to configuration files

=head1 Configuration and Environment

Implements a functional interface

=head1 Subroutines/Functions

=head2 decrypt_from_config

   $plain_text = decrypt_from_config( $params, $password );

Strips the C<{Twofish2}> prefix and then decrypts the password

=head2 encrypt_for_config

   $encrypted_value = encrypt_for_config( $params, $plain_text );

Returns the encrypted value of the plain value prefixed with C<{Twofish2}>
for storage in a configuration file

=head2 is_encrypted

   $bool = is_encrypted( $password_or_encrypted_value );

Return true if the passed argument matches the pattern for an
encrypted value

=head2 __extract_crypt_params

   ($cipher, $password) = __extract_crypt_params( $encrypted_value );

Extracts the cipher name and the encrypted password from the value stored
in the configuration file. Returns the default cipher and null if the
encrypted value does not match the proper pattern. The default cipher is
specified by the L<default cipher|Class::Usul::Crypt/default_cipher> function

=head2 __get_crypt_args

   \%crypt_args = __get_crpyt_args( $params, $cipher );

Returns the argument hash ref passed to L<Class::Usul::Crypt/encrypt>
and L<Class::Usul::Crypt/decrypt>

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Try::Tiny>

=item L<Sub::Exporter::Progressive>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

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
