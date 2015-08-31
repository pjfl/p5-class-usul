package t::boilerplate;

use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' ), catdir( $Bin, 'lib' );

use Test::More;
use Test::Requires { version => 0.88 };
use Module::Build;
use Sys::Hostname;

my ($builder, $host, $notes, $perl_ver);

BEGIN {
   $host     = lc hostname;
   $builder  = eval { Module::Build->current };
   $notes    = $builder ? $builder->notes : {};
   $perl_ver = $notes->{min_perl_version} || 5.008;

   if ($notes->{testing}) {
      $Bin  =~ m{ : .+ : }mx and plan
         skip_all => 'Two colons in $Bin path';
      $host eq 'nwyf.bingosnet.co.uk' and plan
         skip_all => 'Broken smoker 48aff258-06c0-11e5-a85a-e28fcaadd3a7';
      $host =~ m{ \A davids-macbook }mx and plan
         skip_all => 'Broken smoker 158a80fe-0a22-11e5-9d49-e60ed23c8333';
   }
}

use Test::Requires "${perl_ver}";

sub import {
   strict->import;
   $] < 5.008 ? warnings->import : warnings->import( NONFATAL => 'all' );
   return;
}

1;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
