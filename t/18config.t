use t::boilerplate;

use Test::More;
use Scalar::Util qw( blessed );

use_ok 'Class::Usul::Config';

my $osname = lc $^O;
my $conf   = Class::Usul::Config->new
   (  appclass => 'Class::Usul', tempdir  => 't', );

$conf->cfgfiles;
$conf->binsdir;
$conf->logsdir;
$conf->phase;
$conf->root;
$conf->rundir;
$conf->sessdir;
$conf->sharedir;

$osname ne 'mswin32' and $osname ne 'cygwin'
   and is blessed $conf->shell, 'File::DataClass::IO', 'Shell is io object';

like $conf->suid, qr{ \Qusul-admin\E \z }mx, 'Default suid' ;

is $conf->datadir->name, 't', 'Default datadir';

$conf->logfile->exists and $conf->logfile->unlink;

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
