# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) ); # Remove updir if not an example

use Class::Usul::Build;
use Class::Usul::Constants;

# Change these definitions in case of live use

my $MODULE      = q(Class::Usul);
my $HOME_PAGE   = q(http://www.roxsoft.co.uk);
my $LICENSE     = q(perl);
my $LICENSES    = q(http://dev.perl.org/licenses/);
my $TRACKER     = q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=);
my $CONFIGURE   = { 'version'              => '0.77',
                    'Class::Usul'          => '0.1', };
my $RECOMMENDS  = { 'CPAN'                 => '1.9402', };
my $REQUIRES    = { 'File::DataClass'      => '0.1.0',
                    'IPC::SRLock'          => '0.3.144',
                    'Module::Build'        => '0.35',
                    'namespace::autoclean' => '0.09',
                    'namespace::clean'     => '0.11',
                    'version'              => '0.74', };
my $VPATTERN    = 's{ \Q${from}\E \\.%d    }{${to}.%d}gmx; ';
   $VPATTERN   .= 's{ \Q${from}\E \\.\$Rev }{${to}.\$Rev}gmx';

my $build_class = q(Class::Usul::Build);
my $distname    = $build_class->distname( $MODULE );
my $resources   = $build_class->resources( $LICENSES,  $TRACKER,
                                           $HOME_PAGE, $distname );
my $builder     = $build_class->new
   ( add_to_cleanup     => [ q(Debian_CPANTS.txt), q(MANIFEST.bak),
                             $distname.q(-v*), q(Makefile),
                             map { ( q(*/) x $_ ) . q(*~) } 0..5 ],
     build_requires     => { 'version'    => q(0.77),
                             'Test::More' => q(0.74) },
     configure_requires => $CONFIGURE,
     create_packlist    => FALSE,
     create_readme      => TRUE,
     dist_version_from  => $build_class->class_path( $MODULE ),
     license            => $LICENSE,
     module_name        => $MODULE,
     no_index           => { directory => [ qw(t) ] },
     notes              => { version_pattern => $VPATTERN },
     recommands         => $RECOMMENDS,
     requires           => $REQUIRES,
     resources          => $resources,
     sign               => TRUE, );

$builder->create_build_script; # Goal

exit 0;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
