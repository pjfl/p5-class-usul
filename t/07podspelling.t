# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions qw(catdir catfile updir);
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   ! -e catfile( $Bin, updir, q(MANIFEST.SKIP) )
      and plan skip_all => 'POD spelling test only for developers';
}

eval "use Test::Spelling";

$EVAL_ERROR and plan skip_all => 'Test::Spelling required but not installed';

$ENV{TEST_SPELLING}
   or plan skip_all => 'Environment variable TEST_SPELLING not set';

my $checker = has_working_spellchecker(); # Aspell is prefered

if ($checker) { $checker and warn "Check using ${checker}\n" }
else { plan skip_all => 'No OS spell checkers found' }

add_stopwords( <DATA> );

all_pod_files_spelling_ok();

done_testing();

# Local Variables:
# mode: perl
# tab-width: 3
# End:

__DATA__
flanigan
anykey
appdir
appldir
argv
arrayref
async
backend
basename
brk
buildargs
changelog
classdir
classfile
classname
cli
coderef
config
cpan
datetime
debian
distmeta
distname
extns
gettext
getopts
hashref
ids
io
installdeps
isa
json
lbrace
loc
lookup
multi
namespace
nul
pathname
perlbrew
plugins
popen
posix
prepends
runtime
sep
sig
spc
stderr
stdin
stdout
str
suid
svn
symlink
tempdir
tempname
twofish
undef
unescape
uninstall
uninstalls
untaint
untaints
uri
uuid
vcs
yaml
yorn
