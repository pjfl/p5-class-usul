# @(#)$Id$

# Change these definitions in case of live use

my $APPNAME    = q(Class::Usul);
my $HOME_PAGE  = q(http://www.roxsoft.co.uk);
my $LICENSE    = q(perl);
my $LICENSES   = q(http://dev.perl.org/licenses/);
my $TRACKER    = q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=);
my $CONFIGURE  = {
   'version'              => '0.77',
   'Class::Usul'          => '0.1',
};
my $RECOMMENDS = {
   'CPAN'                 => '1.9402',
};
my $REQUIRES   = {
   'File::DataClass'      => '0.1.0',
   'IPC::SRLock'          => '0.3.144',
   'Module::Build'        => '0.35',
   'namespace::autoclean' => '0.09',
   'namespace::clean'     => '0.11',
   'version'              => '0.77',
};
my $VERPAT     = "'s{ \Q${from}\E \\.%d    }{${to}.%d}gmx; ";
   $VERPAT    .= "s{ \Q${from}\E \\.\$Rev }{${to}.\$Rev}gmx'";

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) ); # Remove updir if not an example

use Class::Usul::Build;

my $build_class = q(Class::Usul::Build);
my $distname    = $build_class->distname( $APPNAME );
my $resources   = $build_class->resources( $LICENSES,  $TRACKER,
                                           $HOME_PAGE, $distname );
my $builder     = $build_class->new
   ( add_to_cleanup     => [ q(Debian_CPANTS.txt), q(MANIFEST.bak),
                             $distname.q(-v*), q(Makefile),
                             map { ( q(*/) x $_ ) . q(*~) } 0..5 ],
     build_requires     => { 'version'    => q(0.77),
                             'Test::More' => q(0.74) },
     configure_requires => $CONFIGURE,
     create_packlist    => 0,
     create_readme      => 1,
     dist_version_from  => $build_class->class_path( $APPNAME ),
     license            => $LICENSE,
     module_name        => $APPNAME,
     no_index           => { directory => [ qw(t) ] },
     notes              => { version_pattern => $VERPAT },
     recommands         => $RECOMMENDS,
     requires           => $REQUIRES,
     resources          => $resources, );

$builder->create_build_script; # Goal

exit 0;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
