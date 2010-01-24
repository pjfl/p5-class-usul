# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Test::More;

BEGIN {
   if ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
       || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) {
      plan skip_all => q(CPAN Testing stopped);
   }

   plan tests => 1;
}

my $APPNAME    = q(Class::Usul);
my $HOME_PAGE  = q(http://www.roxsoft.co.uk/);
my $LICENSE    = q(perl);
my $LICENSES   = q(http://dev.perl.org/licenses/);
my $TRACKER    = q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=);
my $CONFIGURE  = { 'version'              => q(0.77),
                   'Class::Usul'          => q(0.4.815), };
my $REQUIRES   = { 'perl'                 => q(5.008),
                   'namespace::autoclean' => q(0.09),
                   'version'              => q(0.77),
                   'Moose'                => q(0.92),
                   'TryCatch'             => q(1.002000),
                   'XML::Simple'          => q(2.18),
};

use_ok q(Class::Usul::Build);

my $build_class = q(Class::Usul::Build);
my $class_path  = catfile( q(lib), split m{ :: }mx, $APPNAME.q(.pm) );
my $distname    = $APPNAME; $distname =~ s{ :: }{-}gmx;
my $repository  = $build_class->public_repository;
my $resources   = { license => $LICENSES, bugtracker => $TRACKER.$distname, };

$HOME_PAGE  and $resources->{homepage  } = $HOME_PAGE;
$repository and $resources->{repository} = $repository;

my $builder = $build_class->new
   ( add_to_cleanup     => [ q(Debian_CPANTS.txt), q(MANIFEST.bak),
                             $distname.q(-v*), q(Makefile),
                             map { ( q(*/) x $_ ) . q(*~) } 0..5 ],
     build_requires     => { 'version'    => q(0.77),
                             'Test::More' => q(0.74) },
     configure_requires => $CONFIGURE,
     create_packlist    => 0,
     create_readme      => 1,
     dist_version_from  => $class_path,
     license            => $LICENSE,
     module_name        => $APPNAME,
     no_index           => { directory => [ qw(t var/root) ] },
     requires           => $REQUIRES,
     resources          => $resources, );

$builder->create_build_script; # Goal

#ok( $prog->app_prefix( q(Test::Application) ) eq q(test_application),
#    q(app_prefix) );

# Local Variables:
# mode: perl
# tab-width: 3
# End:
