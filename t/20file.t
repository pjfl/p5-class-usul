# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.7.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Class::Null;
use Exception::Class ( q(TestException) => { fields => [ qw(arg1 arg2) ] } );
use English qw( -no_match_vars );
use Module::Build;
use Test::More;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

{  package Logger;

   sub new   { return bless {}, __PACKAGE__ }
   sub alert { warn '[ALERT] '.$_[ 1 ] }
   sub debug { warn '[DEBUG] '.$_[ 1 ] }
   sub error { warn '[ERROR] '.$_[ 1 ] }
   sub fatal { warn '[ALERT] '.$_[ 1 ] }
   sub info  { warn '[ALERT] '.$_[ 1 ] }
   sub warn  { warn '[WARNING] '.$_[ 1 ] }
}

use Class::Usul;
use Class::Usul::File;

my $cu = Class::Usul->new( config       => {
                              appclass  => q(Class::Usul),
                              home      => catdir( qw(lib Class Usul) ),
                              localedir => catdir( qw(t locale) ),
                              tempdir   => q(t), },
                           debug        => 0,
                           log          => Logger->new, );

my $cuf = Class::Usul::File->new( builder => $cu );

isa_ok $cuf, 'Class::Usul::File'; is $cuf->tempdir, q(t), 'tempdir';

my $tf = [ qw(t test.xml) ];

ok( (grep { m{ name }msx } $cuf->io( $tf )->getlines)[ 0 ] =~ m{ library }msx,
    'io' );

my $fdcs = $cuf->dataclass_schema->load( $tf );

is $fdcs->{credentials}->{library}->{driver}, q(mysql), 'file_dataclass_schema';

unlink catfile( qw(t ipc_srlock.lck) );
unlink catfile( qw(t ipc_srlock.shm) );

is $cuf->status_for( $tf )->{size}, 237, 'status_for';

my $symlink = catfile( qw(t symlink) );

$cuf->symlink( q(t), q(test.xml), [ qw(t symlink) ] );

ok -e $symlink, 'symlink'; -e _ and unlink $symlink;

my $tempfile = $cuf->tempfile;

ok( $tempfile, q(call/tempfile) );

is ref $tempfile->io_handle, q(File::Temp), 'tempfile';

$cuf->io( $tempfile->pathname )->touch;

ok( -f $tempfile->pathname, q(touch/tempfile) );

$cuf->delete_tmp_files;

ok( ! -f $tempfile->pathname, q(delete_tmp_files) );

ok $cuf->tempname =~ m{ $PID .{4} }msx, 'tempname';

my $io = $cuf->io( q(t) ); my $entry;

while (defined ($entry = $io->next)) {
   $entry->filename eq q(10functions.t) and last;
}

ok defined $entry && $entry->filename eq q(10functions.t), 'IO::next';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
