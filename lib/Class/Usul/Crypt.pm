# @(#)$Id$

package Class::Usul::Crypt;

use strict;
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Constants;
use Crypt::CBC;
use English qw(-no_match_vars);
use MIME::Base64;
use Moose::Role;
use Sys::Hostname;

requires qw(create_token);

my $CLEANER = '.*^\s*use\s+Acme::Bleach\s*;\r*\n';
my $KEY     = " \t" x 8;
my $DATA    = do { local $RS = undef; <DATA> };

sub decrypt {
   my ($self, $seed, $encoded) = @_; $encoded or return;

   my $cipher = Crypt::CBC->new( -cipher => q(Twofish),
                                 -key    => $self->keygen( $seed ) );

   return $cipher->decrypt( decode_base64( $encoded ) );
}

sub encrypt {
   my ($self, $seed, $plain) = @_; $plain or return;

   my $cipher = Crypt::CBC->new( -cipher => q(Twofish),
                                 -key    => $self->keygen( $seed ) );

   return encode_base64( $cipher->encrypt( $plain ), NUL );
}

sub keygen {
   my ($self, $args) = @_;

   $args = { seed => $args || NUL } unless ($args and ref $args eq HASH);

   (my $salt = __inflate( $args->{data} || $DATA )) =~ s{ $CLEANER }{}msx;

   ## no critic
   return substr $self->create_token( ( eval $salt ).$args->{seed} ), 0, 32;
   ## critic
}

# Private subroutines

sub __inflate {
   local $_ = pop; s{ \A $KEY|[^ \t] }{}gmx; tr{ \t}{01}; return pack 'b*', $_;
}

1;

=pod

=head1 Name

Class::Usul::Crypt - Encryption/decryption class methods

=head1 Version

0.2.$Revision$

=head1 Synopsis

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 decrypt

   my $plain = $self->decrypt( $seed, $encoded );

Decodes and decrypts the C<$encoded> argument and returns the plain
text result. See the C<encrypt> method

=head2 encrypt

   my $encrypted = $self->encrypt( $seed, $plain );

Encrypts the plain text passed in the C<$plain> argument and returns
it Base64 encoded. L<Crypt::Twofish_PP> is used to do the encryption. The
C<$seed> argument is passed to the C<keygen> method

=head2 keygen

Generates the key used by the C<encrypt> and C<decrypt> methods. Calls
C<_inflate> to create the salt. Note that the salt is C<eval>'d in string
context

=head2 _inflate

Lifted from L<Acme::Bleach> this recovers the default salt for the key
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

__DATA__
			  	   
  		 	 	 
 		 	 			
  	   			
 	     	 
		 				 	
	 		  			
   	 			 
 			 		 	
    		 	 
		 		 	 	
  		  			
 	  			  
	   	 		 
	  	 		 	
 	  		 	 
			  	  
