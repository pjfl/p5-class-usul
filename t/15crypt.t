use t::boilerplate;

use Test::More;

use_ok 'Class::Usul::Crypt', qw( decrypt encrypt );

my $plain_text            = 'Hello World';
my $args                  = { cipher => 'Twofish2', salt => 'salt' };
my $base64_encrypted_text = encrypt( $args, $plain_text );

is decrypt( $args, $base64_encrypted_text ), $plain_text, 'Default seed';

$base64_encrypted_text = encrypt( undef, $plain_text );

is decrypt( undef, $base64_encrypted_text), $plain_text, 'Default everything';

$base64_encrypted_text = encrypt( 'test', $plain_text );

is decrypt( 'test', $base64_encrypted_text), $plain_text, 'User password';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
