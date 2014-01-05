# @(#)Ident: 25prompt.t 2013-12-06 16:29 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.34.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );

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

use_ok 'Class::Usul::Programs';

my $prog    = Class::Usul::Programs->new( appclass => 'Class::Usul',
                                          config   => { logsdir => 't',
                                                        tempdir => 't', },
                                          noask    => 1,
                                          quiet    => 1, );

$ENV{PERL_MM_USE_DEFAULT} = 1; close \*STDIN;

ok !$prog->is_interactive, 'Is not interactive';
is $prog->anykey, 1, 'Any key';
is $prog->get_line( undef, 'test' ), 'test', 'Get line';
is $prog->get_option( undef, 2 ), 1, 'Get option';
is $prog->yorn( undef, 1 ), 1, 'Yes or no';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
