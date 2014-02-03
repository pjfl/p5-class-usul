use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

use Test::More;
use Test::Requires { version => 0.88 };
use Module::Build;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";
use English qw( -no_match_vars );

{  package MyTest;

   use Moo;
   use Class::Usul::Options;

   option 'bool'    => is => 'ro', default       => 0;
   option 'counter' => is => 'ro', repeatable    => 1;
   option 'help'    => is => 'ro', documentation => 'This is help';
   option 'empty'   => is => 'ro', negateable    => 1;
   option 'int'     => is => 'ro', default       => 1,         format => 'i';
   option 'json'    => is => 'ro', json          => 1,
   option 'order2'  => is => 'ro', order         => 2,
   option 'order1'  => is => 'ro', order         => 1,
   option 'short'   => is => 'ro', repeatable    => 1,         short  => 's',
   option 'split'   => is => 'ro', autosplit     => ',',       format => 'i@';
   option 'string'  => is => 'ro', default       => 'default', format => 's';
   option 'str_req' => is => 'ro', required      => 1,         format => 's';
}

@ARGV = ( qw( --bool --counter --counter --empty --no-empty --int 2 --json ),
          '{ "key": "value" }', qw( --short -s --split 1 --split=2 --split ),
          '3,4', qw( --string cmdline --str-req=ok 1 2 ) );

my $t = MyTest->new_with_options;

is_deeply $t->split, [ 1, 2, 3, 4 ], 'autosplit option';
is $t->bool, 1, 'bool option';
like $t->options_usage, qr{ This \s is \s help }mx, 'documentation option';
is $t->int, 2, 'integer option';
is $t->json->{key}, 'value', 'json option';
is $t->empty, 0, 'negateable option';
is $t->counter, 2, 'repeatable option';
like $t->options_usage, qr{ order1 .+ order1 .+ order2 .+ order2 }msx,
   'order option';
is $t->short, 2, 'short option';
is $t->string, 'cmdline', 'string option';

is $t->extra_argv->[ 0 ], 1, 'extra_argv 0';
is $t->extra_argv->[ 1 ], 2, 'extra_argv 1';
is $t->next_argv, 1, 'next_argv';

$t->unshift_argv( 3 );

is $t->extra_argv->[ 0 ], 3, 'unshift_argv';

@ARGV = ();

eval { MyTest->new_with_options }; my $e = $EVAL_ERROR;

like $e, qr{ Missing \s required \s arguments }mx, 'str_req is missing';

# TODO: Skip_options prefer_cmdline protect_argv flavour untaint_cmdline

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
