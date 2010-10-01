# @(#)$Id$
# Definitions. Change these in case of live use

my $SIGN        = 1;
my $LICENSE     = q(perl);
my $MODULE      = q(Class::Usul);
my $HOME_PAGE   = q(http://www.roxsoft.co.uk);
my $TRACKER     = q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=);
my $REQUIRES    = { 'File::DataClass'      => q(0.1.0),
                    'IPC::SRLock'          => q(0.3.0),
                    'Module::Build'        => 0.35,
                    'namespace::autoclean' => 0.09,
                    'namespace::clean'     => 0.11,
                    'version'              => 0.74, };
my $RECOMMENDS  = { 'CPAN'                 => 1.9402, };
my $CONFIGURE   = { 'version'              => 0.77,
                    'Class::Usul'          => q(0.1.0), };
my $BUILDREQS   = { 'Test::More'           => 0.74,
                    'version'              => 0.77, };
my $VPATTERN    = 's{ \Q${from}\E \\.%d    }{${to}.%d}gmx; ';
   $VPATTERN   .= 's{ \Q${from}\E \\.\$Rev }{${to}.\$Rev}gmx';

# Boilerplate

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) ); # Remove updir if not an example

use Class::Usul::Build;
use Class::Usul::Constants;

sub testing { !! ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
              || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) }

my $build_class = q(Class::Usul::Build);
my $distname    = $build_class->distname( $MODULE );
my $resources   = $build_class->resources( q(http://dev.perl.org/licenses/),
                                           $TRACKER, $HOME_PAGE, $distname );
$build_class->new
   ( add_to_cleanup     => [ q(Debian_CPANTS.txt), q(MANIFEST.bak),
                             $distname.q(-*.gz), q(Makefile),
                             map { ( q(*/) x $_ ) . q(*~) } 0..5 ],
     build_requires     => $BUILDREQS,
     configure_requires => $CONFIGURE,
     create_license     => TRUE,
     create_packlist    => FALSE,
     create_readme      => TRUE,
     dist_version_from  => $build_class->class_path( $MODULE ),
     license            => $LICENSE,
     module_name        => $MODULE,
     no_index           => { directory       => [ qw(t) ], },
     notes              => { stop_tests      => testing,
                             version_pattern => $VPATTERN, },
     recommands         => $RECOMMENDS,
     requires           => $REQUIRES,
     resources          => $resources,
     sign               => $SIGN, )->create_build_script; # Goal

# Local Variables:
# mode: perl
# tab-width: 3
# End:
