# @(#)$Id$

package Class::Usul::Crypt;

use strict;
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions qw(create_token is_hashref);
use Crypt::CBC;
use English qw(-no_match_vars);
use MIME::Base64;
use Sys::Hostname;

use Sub::Exporter -setup => {
   exports => [ qw(decrypt encrypt cipher_list default_cipher) ],
   groups  => { default => [], },
};

my $SEED = do { local $RS = undef; <DATA> };

sub decrypt (;$$) {
   $_[ 0 ] ? __f0( $_[ 0 ] )->decrypt( decode_base64( $_[ 1 ] ) ) : $_[ 0 ];
}

sub encrypt (;$$) {
   $_[ 0 ] ? encode_base64( __f0( $_[ 0 ] )->encrypt( $_[ 1 ] ), '' ) : $_[ 0 ];
}

sub cipher_list () {
   ( qw(Blowfish Rijndael Twofish) );
}

sub default_cipher () {
   q(Twofish);
}

# Private functions

sub __f0 {
   Crypt::CBC->new( -cipher => __f1( $_[ 0 ] ), -key => __f2( $_[ 0 ] ) );
}

sub __f1 {
   (is_hashref $_[ 0 ]) ? $_[ 0 ]->{cipher} || default_cipher : default_cipher;
}

sub __f2 {
   substr create_token( __f3( pop ) ), 0, 32;
}

sub __f3 {
   __f4( (is_hashref $_[ 0 ]) ? $_[ 0 ] : { salt => $_[ 0 ] || '' } );
}

sub __f4 {
   __f5( $_[ 0 ]->{seed} || $SEED ).$_[ 0 ]->{salt};
}

sub __f5 {
   my $y = pop; my $x = " \t" x 8; $y =~ s{^$x|[^ \t]}{}g; __f6( $y );
}

sub __f6 {
   my $y = pop; $y =~ tr{ \t}{01}; __f7( pack 'b*', $y );
}

sub __f7 {
   my $y = pop; my $x = __f8(); $y =~ s{$x}{}sm; eval $y;
}

sub __f8 {
   my $y = __f9(); $y =~ tr{a-zA-Z}{n-za-mN-ZA-M}; $y;
}

sub __f9 {
   '.*^\f*hfr\f+Npzr::Oyrnpu\f*;\e*\a';
}

1;

=pod

=head1 Name

Class::Usul::Crypt - Encryption/decryption functions

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use Class::Usul::Crypt qw(decrypt encrypt);

   my $key = q(); # OR
   my $key = 'my_little_secret'; # OR
   my $key = { salt => 'my_little_secret', seed => 'whiten this' };

   my $base64_encrypted_text = encrypt( $key, $plain_text, [ $cipher ] );

   my $plain_text = decrypt( $key, $base64_encrypted_text );

=head1 Description

Exports a pair of functions to encrypt/decrypt data. Obfuscates the default
encryption key

=head1 Configuration and Environment

The C<$key> can be a string (including the null string) or a hash ref with
I<salt> and I<seed> keys

=head1 Subroutines/Methods

=head2 decrypt

   my $plain = decrypt( $salt || \%params, $encoded );

Decodes and decrypts the C<$encoded> argument and returns the plain
text result. See the L</encrypt> method

=head2 encrypt

   my $encrypted = encrypt( $salt || \%params, $plain, [ $cipher ] );

Encrypts the plain text passed in the C<$plain> argument and returns
it Base64 encoded. By default L<Crypt::Twofish> is used to do the
encryption. The optional C<$cipher> argument overrides this

=head2 cipher_list

   @list_of_ciphers = cipher_list();

Returns the list of ciphers supported by L<Crypt::CBC>. These may not
all be installed

=head2 default_cipher

   $ciper_name = default_cipher();

Returns I<Twofish>

=head2 __f0 .. __f9

Lifted from L<Acme::Bleach> this recovers the default seed for the key
generator

Generates the key used by the C<encrypt> and C<decrypt> methods. The
seed is C<eval>'d in string context and then the salt is concantented
onto it before being passed to
C<Class::Usul::Functions/create_token>. Uses this value as the key for
a L<Crypt::CBC> object which it creates and returns

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Crypt::CBC>

=item L<Crypt::Twofish>

=item L<MIME::Base64>

=item L<Sub::Exporter>

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

__DATA__
			  	   
  		 	 	 
 		 	 			
  	   			
 	     	 
		 				 	
	 		  			
   	 			 
 			 		 	
    		 	 
		 		 	 	
  		  			
 	  			  
	   	 		 
	  	 		 	
 	  		 	 
			  	  
