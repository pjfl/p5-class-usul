# @(#)Ident: 10excepton.t 2013-04-26 19:32 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Module::Build;
use Test::More;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use Class::Null;
use Class::Usul::Exception;

eval { Class::Usul::Exception->throw_on_error }; my $e = $EVAL_ERROR;

ok ! $e, 'No throw without error';

eval { Class::Usul::Exception->throw_on_error( 'PracticeKill' ) };

$e = $EVAL_ERROR; like $e, qr{ PracticeKill \s* \z }mx, 'Throws on error';

is ref $e, 'Class::Usul::Exception', 'Good class';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
