# @(#)$Ident: 22crypt.t 2013-08-18 11:06 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.28.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );

use Module::Build;
use Test::More;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";

use_ok 'Class::Usul::Crypt', qw( decrypt encrypt );

my $plain_text            = 'Hello World';
my $args                  = { cipher => 'Twofish2', salt => 'salt' };
my $base64_encrypted_text = encrypt( $args, $plain_text );

is decrypt( $args, $base64_encrypted_text ), $plain_text, 'Round trips';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
