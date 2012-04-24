# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use English qw(-no_match_vars);
use File::Basename qw(basename);
use Test::More;
use Test::Deep;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use Class::Usul::Programs;

my $name    = basename( $0, qw(.t) );
my $logfile = catfile( qw(t test.log) );
my $prog    = Class::Usul::Programs->new( appclass => q(Class::Usul),
                                          logfile  => $logfile,
                                          method   => q(dump_self),
                                          nodebug  => 1,
                                          quiet    => 1,
                                          tempdir  => q(t), );

cmp_deeply $prog, methods( encoding => q(UTF-8) ), 'Constructs default object';

is $prog->config->script, $name.q(.t), 'Config->script';

is $prog->config->name, $name, 'Config->name';

is $prog->add_leader(), "${name}: [no message]", 'Default leader';

is $prog->add_leader( 'Dummy' ), '10base: Dummy', 'Text plus leader';

is $prog->can_call( 'dump_self' ), 1, 'Can call true';

is $prog->can_call( 'add_leader' ), 0, 'Can call false';

is $prog->get_meta( q(META.yml) )->name, q(Class-Usul), 'Meta file class';

eval { $prog->file->io( 'Dummy' )->all }; my $e = $EVAL_ERROR || q();

like $e, qr{ Dummy \s+ cannot \s+ open }mx, 'Non existant file';

is ref $e, 'File::DataClass::Exception', 'File exception class';

unlink $logfile; my $io = $prog->file->io( $logfile ); $io->touch;

ok -f $logfile, 'Create logfile'; $prog->info( 'Information' );

like $io->chomp->getline, qr{ \[INFO\] \s Information }mx, 'Read logfile';

unlink $logfile;

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
