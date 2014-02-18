package Class::Usul::Crypt;

use strict;
use warnings;

use Class::Usul::Constants;
use Class::Usul::Functions qw( create_token is_coderef is_hashref );
use Crypt::CBC;
use English                qw( -no_match_vars );
use Exporter 5.57          qw( import );
use MIME::Base64;
use Sys::Hostname;

our @EXPORT_OK = qw( cipher_list decrypt default_cipher encrypt );

my $SEED = do { local $RS = undef; <DATA> };

# Public functions
sub cipher_list () {
   return ( qw( Blowfish Rijndael Twofish2 ) );
}

sub decrypt (;$$) {
   return __cipher( $_[ 0 ] )->decrypt( decode_base64( $_[ 1 ] ) );
}

sub default_cipher () {
   return 'Twofish2';
}

sub encrypt (;$$) {
   return encode_base64( __cipher( $_[ 0 ] )->encrypt( $_[ 1 ] ), NUL );
}

# Private functions
sub __cipher {
   Crypt::CBC->new( -cipher => __cname( $_[ 0 ] ), -key => __wards( $_[ 0 ] ) );
}

sub __cname {
   (is_hashref $_[ 0 ]) ? $_[ 0 ]->{cipher} || default_cipher : default_cipher;
}

sub __wards {
   (is_hashref $_[ 0 ]) || !$_[ 0 ] ? __token( $_[ 0 ] ) : $_[ 0 ];
}

sub __token {
   substr create_token( __compose( $_[ 0 ] || {} ) ), 0, 32;
}

sub __compose {
   __evaluate( __deref( $_[ 0 ]->{seed} ) || $SEED ).__deref( $_[ 0 ]->{salt} );
}

sub __deref {
   (is_coderef $_[ 0 ]) ? ($_[ 0 ]->() // NUL) : ($_[ 0 ] // NUL);
}

sub __evaluate {
   my $x = __prepare( $_[ 0 ] ); $x ? ((eval __decode( $x )) || NUL) : NUL;
}

sub __prepare {
   my $y = $_[ 0 ]; my $x = " \t" x 8; $y =~ s{^$x|[^ \t]}{}g; $y;
}

sub __decode {
   my $y = $_[ 0 ]; $y =~ tr{ \t}{01}; pack 'b*', $y;
}

1;

=pod

=head1 Name

Class::Usul::Crypt - Encryption/decryption functions

=head1 Synopsis

   use Class::Usul::Crypt qw(decrypt encrypt);

   my $args = q(); # OR
   my $args = 'salt'; # OR
   my $args = { salt => 'salt', seed => 'whiten this' };

   $args->{cipher} = 'Twofish2'; # Optionally

   my $base64_encrypted_text = encrypt( $args, $plain_text );

   my $plain_text = decrypt( $args, $base64_encrypted_text );

=head1 Description

Exports a pair of functions to encrypt/decrypt data. Obfuscates the default
encryption key

=head1 Configuration and Environment

The C<$key> can be a string (including the null string) or a hash ref with
I<salt> and I<seed> keys. The I<seed> attribute can be a code ref in which
case it will be called with no argument and the return value used

=head1 Subroutines/Methods

=head2 decrypt

   my $plain = decrypt( $salt || \%params, $encoded );

Decodes and decrypts the C<$encoded> argument and returns the plain
text result. See the L</encrypt> method

=head2 encrypt

   my $encoded = encrypt( $salt || \%params, $plain );

Encrypts the plain text passed in the C<$plain> argument and returns
it Base64 encoded. By default L<Crypt::Twofish2> is used to do the
encryption. The optional C<< $params->{cipher} >> attribute overrides this

=head2 cipher_list

   @list_of_ciphers = cipher_list();

Returns the list of ciphers supported by L<Crypt::CBC>. These may not
all be installed

=head2 default_cipher

   $ciper_name = default_cipher();

Returns I<Twofish2>

=head2 __cipher

Lifted from L<Acme::Bleach> this recovers the default seed for the key
generator

Generates the key used by the C<encrypt> and C<decrypt> methods. The
seed is C<eval>'d in string context and then the salt is concatenated
onto it before being passed to
C<Class::Usul::Functions/create_token>. Uses this value as the key for
a L<Crypt::CBC> object which it creates and returns

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Crypt::CBC>

=item L<Crypt::Twofish2>

=item L<Exporter>

=item L<MIME::Base64>

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

__DATA__
			  	   
  		 	 	 
 		 	 			
  	   			
 	     	 
		 				 	
	 		  			
   	 			 
 			 		 	
    		 	 
		 		 	 	
  		  			
 	  			  
	   	 		 
	  	 		 	
 	  		 	 
			  	  
