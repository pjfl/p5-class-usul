# @(#)$Ident: 12l10n.t 2013-12-06 16:25 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.35.%d', q$Rev: 0 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir catfile updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );
use utf8;

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
use English qw( -no_match_vars );

{  package Logger;

   sub new   { return bless {}, __PACKAGE__ }
   sub alert { warn '[ALERT] '.$_[ 1 ] }
   sub debug { warn '[DEBUG] '.$_[ 1 ] }
   sub error { warn '[ERROR] '.$_[ 1 ] }
   sub fatal { warn '[ALERT] '.$_[ 1 ] }
   sub info  { warn '[ALERT] '.$_[ 1 ] }
   sub warn  { warn '[WARNING] '.$_[ 1 ] }
}

use Class::Usul::L10N;

my $l10n = Class::Usul::L10N->new( debug        => 0,
                                   domain_names => [ q(default) ],
                                   localedir    => catdir( qw(t locale) ),
                                   log          => Logger->new,
                                   tempdir      => q(t) );
my $args = { locale => 'de_DE' };
my $text = $l10n->localize( 'December', $args );

ok $text eq 'Dezember', 'translated';

$text = $l10n->localize( 'September', $args );
ok $text eq 'September', 'same';

$text = $l10n->localize( 'Not translated', $args );
ok $text eq 'Not translated', 'not translated';

$text = $l10n->localize( 'March', $args );
ok $text eq 'März', 'charset decode';

$args->{context} = 'Context here (2)';
$text = $l10n->localize( 'Singular', $args );
ok $text eq 'Einzahl 2', 'context';

$args->{count} = 2;
$text = $l10n->localize( 'Singular', $args );
ok $text eq 'Mehrzahl 2', 'context plural';

my $header = $l10n->get_po_header( $args );

ok $header->{project_id_version} eq q(libintl-perl-text 1.12),
   'get_po_header';

unlink catfile( qw( t file-dataclass-schema.dat ) );

done_testing;

# Local Variables:
# coding: utf-8
# mode: perl
# tab-width: 3
# End:
