use utf8;
use t::boilerplate;

use Test::More;
use Test::Requires        qw( Hash::MoreUtils );
use English               qw( -no_match_vars );
use File::Spec::Functions qw( catdir catfile );

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

my $l10n = Class::Usul::L10N->new( debug           => 0,
                                   l10n_attributes => {
                                      domains      => [ 'default' ], },
                                   localedir       => catdir( qw( t locale ) ),
                                   log             => Logger->new,
                                   tempdir         => 't' );
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

$text = $l10n->localizer( 'de_DE', 'December [_1]', '1st' );
ok $text eq 'Dezember 1st', 'localizer';

$text = $l10n->localizer( 'de_DE', 'December [_1]', [ '1st' ] );
ok $text eq 'Dezember 1st', 'localizer - arrayref';

$text = $l10n->localizer( 'de_DE', 'December [_1]', { params => [ '1st' ] } );
ok $text eq 'Dezember 1st', 'localizer - hashref';

unlink catfile( qw( t file-dataclass-schema.dat ) );

done_testing;

# Local Variables:
# coding: utf-8
# mode: perl
# tab-width: 3
# End:
