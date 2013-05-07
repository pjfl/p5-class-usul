# @(#)$Ident: 18programs.t 2013-04-29 19:20 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.18.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use English qw(-no_match_vars);
use File::Basename qw(basename);
use Test::Deep;

use Class::Usul::Programs;
use Class::Usul::Functions qw(say);

my $name    = basename( $0, qw(.t) );
my $logfile = catfile( q(t), $name.q(.log) );
my $prog    = Class::Usul::Programs->new( appclass => q(Class::Usul),
                                          config   => { logsdir => q(t),
                                                        tempdir => q(t), },
                                          method   => q(dump_self),
                                          nodebug  => 1,
                                          quiet    => 1, );

cmp_deeply $prog, methods( encoding => q(UTF-8) ), 'Constructs default object';

is $prog->config->script, $name.q(.t), 'Config->script';

is $prog->config->name, $name, 'Config->name';

is $prog->add_leader(), '', 'Default leader';

is $prog->add_leader( 'Dummy' ), '18programs: Dummy', 'Text plus leader';

is $prog->can_call( 'dump_self' ), 1, 'Can call true';

is $prog->can_call( 'add_leader' ), 0, 'Can call false';

my $meta = $prog->get_meta;

is $meta->name, q(Class-Usul), 'Meta file class';

like $meta->license->[ 0 ], qr{ perl }mx, 'Meta license';

eval { $prog->file->io( 'Dummy' )->all }; my $e = $EVAL_ERROR || q();

like $e, qr{ Dummy \s+ cannot \s+ open }mx, 'Non existant file';

is ref $e, 'Class::Usul::Exception', 'Our exception class';

unlink $logfile; my $io = $prog->file->io( $logfile ); $io->touch;

ok -f $logfile, 'Create logfile'; $prog->info( 'Information' );

like $io->chomp->getline, qr{ \[INFO\] \s Information }mx, 'Read logfile';

unlink $logfile;

is $prog->debug, 0, 'Debug false';

$prog->debug( 1 );

is $prog->debug, 1, 'Debug true';

done_testing;

#$prog->run;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
