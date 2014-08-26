use strict;
use warnings;
use File::Spec::Functions qw( catdir catfile updir );
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
use Capture::Tiny  qw( capture );
use English        qw( -no_match_vars );
use File::DataClass::IO;
use File::Basename qw( basename );
use Test::Deep;
use Class::Usul::Functions qw( find_source );

use_ok 'Class::Usul::Programs';

my $name    = basename( $0, qw( .t ) );
my $logfile = catfile( 't', "${name}.log" );
my $prog    = Class::Usul::Programs->new
   (  appclass => 'Class::Usul',
      config   => { logsdir => 't', tempdir => 't', },
      method   => 'dump_self',
      noask    => 1,
      quiet    => 1, );

cmp_deeply $prog, methods( encoding => 'UTF-8' ), 'Constructs default object';
is $prog->config->script, "${name}.t", 'Config->script';
is $prog->config->name, $name, 'Config->name';
is $prog->add_leader(), '', 'Default leader';
is $prog->add_leader( 'Dummy' ), '18programs: Dummy', 'Text plus leader';
is $prog->can_call( 'dump_self' ), 1, 'Can call true';
is $prog->can_call( 'add_leader' ), 0, 'Can call false';

eval { io( 'Dummy' )->all }; my $e = $EVAL_ERROR || q();

like $e, qr{ 'Dummy' \s+ cannot \s+ open }mx, 'Non existant file';
is   ref $e, 'Class::Usul::Exception', 'Our exception class';

unlink $logfile; my $io = io( $logfile ); $io->touch;

ok   -f $logfile, 'Create logfile'; $prog->info( 'Information' );
like $io->chomp->getline, qr{ \[INFO\] \s Information }mx, 'Read logfile';

unlink $logfile;

is   $prog->debug, 0, 'Debug false';
is   $prog->debug_flag, '-n', 'Debug flag - false';

$prog->debug( 1 );

is   $prog->debug, 1, 'Debug true';
is   $prog->debug_flag, '-D', 'Debug flag - true';

my ($out, $err) = capture { $prog->run };

like $err, qr{ Class::Usul::Programs }mx, 'Runs dump self';
like $prog->options_usage, qr{ Did \s we \s forget }mx, 'Default options usage';
is   ref $prog->os, 'HASH', 'Has OS hash';

my $path = find_source 'Class::Usul::Functions';

SKIP: {
   $path or (is_win32() and skip 'Possible NTFS issue', 1);

   $prog = Class::Usul::Programs->new
      (  appclass => 'Class::Usul',
         config   => { logsdir => 't',
                       tempdir => 't', },
         method   => 'list_methods',
         noask    => 1,
         quiet    => 1, );

   ($out, $err) = capture { $prog->run };
   like $out, qr{ available \s command \s line }mx, 'Runs list methods';
   ($out, $err) = capture { $prog->error };
   like $err, qr{ no \s message }mx, 'Default error';
}

done_testing;

unlink $logfile;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
