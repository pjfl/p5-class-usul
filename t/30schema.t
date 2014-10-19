use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

use Test::More;
use Test::Requires { version => 0.88 };
use Module::Build;

my $builder; my $notes = {}; my $perl_ver;

BEGIN {
   $builder   = eval { Module::Build->current };
   $builder and $notes = $builder->notes;
   $perl_ver  = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";

use_ok 'Class::Usul::Schema';

my $prog = Class::Usul::Schema->new( {
   config   => { ctrldir => 't' },
   database => 'test',
   noask    => 1,
} );

is $prog->db_attr->{no_comments}, 1, 'Database attributes';
is $prog->driver, 'mysql', 'Driver';
is $prog->dsn, 'dbi:mysql:database=test;host=localhost;port=3306', 'DSN';
is $prog->host, 'localhost', 'Host';
is $prog->password, 'test', 'Password';
is $prog->user, 'root', 'User';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
