# @(#)$Ident: 22crypt.t 2013-08-13 23:13 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.24.%d', q$Rev: 2 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

my $notes = {};

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
}

use_ok 'Class::Usul::Crypt', qw(decrypt encrypt);

my $plain_text            = 'Hello World';
my $args                  = { cipher => 'Twofish2', salt => 'salt' };
my $base64_encrypted_text = encrypt( $args, $plain_text );

is decrypt( $args, $base64_encrypted_text ), $plain_text, 'Round trips';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
