# @(#)Ident: 30loading_classes.t 2013-11-22 15:18 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.33.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir catfile updir );
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

use Test::Requires         "${perl_ver}";
use Class::Usul::Functions qw( exception );
use File::Basename         qw( basename );

{  package MyProg;

   use Moo;

   extends 'Class::Usul::Programs';
   with    'Class::Usul::TraitFor::LoadingClasses';

   1;
}

my $name    = basename( $0, qw( .t ) );
my $logfile = catfile( 't', "${name}.log" );
my $prog    = MyProg->new( appclass => 'Class::Usul',
                           config   => { logsdir => 't', tempdir => 't', },
                           method   => 'dump_self',
                           noask    => 1,
                           quiet    => 1, );

$prog->build_subcomponents( 'Class::Usul::Config' );

is $prog->config->pwidth, 60, 'build_subcomponents';

$prog->setup_plugins;

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
