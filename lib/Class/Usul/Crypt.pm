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
   exports => [ qw(decrypt encrypt) ], groups => { default => [], },
};

my $CLEANER = '.*^\s*use\s+Acme::Bleach\s*;\r*\n';
my $DATA    = do { local $RS = undef; <DATA> };
my $KEY     = " \t" x 8;

sub decrypt (;$$) {
   my ($key, $encoded) = @_; $encoded or return; $key = __keygen( $key );

   my $cipher = Crypt::CBC->new( -cipher => q(Twofish), -key => $key );

   return $cipher->decrypt( decode_base64( $encoded ) );
}

sub encrypt (;$$) {
   my ($key, $plain) = @_; $plain or return; $key = __keygen( $key );

   my $cipher = Crypt::CBC->new( -cipher => q(Twofish), -key => $key );

   return encode_base64( $cipher->encrypt( $plain ), NUL );
}

# Private functions

sub __keygen {
   my $args = shift; is_hashref $args or $args = { salt => $args || NUL };

  (my $seed = __inflate( $args->{seed} || $DATA )) =~ s{ $CLEANER }{}msx;
   ## no critic
   return substr create_token( ( eval $seed ).$args->{salt} ), 0, 32;
   ## critic
}

sub __inflate {
   local $_ = pop; s{ \A $KEY|[^ \t] }{}gmx; tr{ \t}{01}; return pack 'b*', $_;
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

   my $base64_encrypted_text = encrypt( $key, $plain_text );

   my $plain_text = decrypt( $key, $base64_encrypted_text );

=head1 Description

Exports a pair of functions to encrypt/decrypt data

=head1 Configuration and Environment

The C<$key> can be a string (including the null string) or a hash ref with
I<salt> and I<seed> keys

=head1 Subroutines/Methods

=head2 decrypt

   my $plain = decrypt( $key, $encoded );

Decodes and decrypts the C<$encoded> argument and returns the plain
text result. See the C<encrypt> method

=head2 encrypt

   my $encrypted = encrypt( $key, $plain );

Encrypts the plain text passed in the C<$plain> argument and returns
it Base64 encoded. L<Crypt::Twofish_PP> is used to do the encryption. The
C<$key> argument is passed to the C<__keygen> method

=head2 __keygen

Generates the key used by the C<encrypt> and C<decrypt> methods. Calls
C<__inflate> to create the seed. The seed is C<eval>'d in string
context and then the salt is concantented onto it before being passed to
C<Class::Usul::Functions/create_token>

=head2 __inflate

Lifted from L<Acme::Bleach> this recovers the default seed for the key
generator

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Crypt::CBC>

=item L<Crypt::Twofish>

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
			  	   
  		 	 	 
 		 	 			
  	   			
 	     	 
		 				 	
	 		  			
   	 			 
 			 		 	
    		 	 
		 		 	 	
  		  			
 	  			  
	   	 		 
	  	 		 	
 	  		 	 
			  	  
