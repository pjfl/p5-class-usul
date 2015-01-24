use t::boilerplate;

use Test::More;

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
