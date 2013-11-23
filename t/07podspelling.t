# @(#)Ident: 07podspelling.t 2013-08-13 23:16 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.33.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions qw(catdir catfile updir);
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   $ENV{AUTHOR_TESTING}
      or plan skip_all => 'POD spelling test only for developers';
}

eval "use Test::Spelling";

$EVAL_ERROR and plan skip_all => 'Test::Spelling required but not installed';

$ENV{TEST_SPELLING}
   or plan skip_all => 'Environment variable TEST_SPELLING not set';

my $checker = has_working_spellchecker(); # Aspell is prefered

if ($checker) { warn "Check using ${checker}\n" }
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
api
appdir
appldir
argv
arrayref
async
backend
basename
brk
bson
bsonid
buildargs
canonicalise
canonicalised
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
fh
fqdn
fullname
gecos
gettext
getopts
hashref
hostname
ids
io
installdeps
isa
json
lbrace
loc
loginid
logname
lookup
MSWin
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
stacktrace
stderr
stdin
stdout
str
stringifies
suid
svn
symlink
tempdir
tempname
Twofish
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
