use t::boilerplate;

use Test::More;
use File::DataClass::IO;

use_ok 'Class::Usul::Log';

my $file = io [ 't', 'test.log' ]; $file->exists and $file->unlink;
my $log  = Class::Usul::Log->new( encoding => 'UTF-8', logfile => $file );

$log->debug( 'test' );
unlike $file->all, qr{ \Q[DEBUG] Test\E }msx, 'Does not log debug level';
$log->info ( 'test' );
like $file->all, qr{ \Q[INFO] Test\E }msx, 'Log info level';
$log->warn ( 'test' );
like $file->all, qr{ \Q[WARNING] Test\E }msx, 'Log warning level';
$log->error( 'test' );
like $file->all, qr{ \Q[ERROR] Test\E }msx, 'Log error level';
$log->alert( 'test' );
like $file->all, qr{ \Q[ALERT] Test\E }msx, 'Log alert level';
$log->fatal( 'test' );
like $file->all, qr{ \Q[FATAL] Test\E }msx, 'Log fatal level';

$log = Class::Usul::Log->new
   ( debug => 1, encoding => 'UTF-8', logfile => $file );

$log->debug( 'test' );
like $file->all, qr{ \Q[DEBUG] Test\E }msx, 'Log debug level';

$file->exists and $file->unlink;
done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
