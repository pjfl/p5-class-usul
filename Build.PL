# @(#)$Id$

my $MODULE     = q(Class::Usul);
my $HOME_PAGE  = q(http://www.roxsoft.co.uk);
my $LICENSE    = q(http://dev.perl.org/licenses/);
my $TRACKER    = q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=);
my $REQUIRES   = {
   'perl'                 => 5.008,
   'namespace::autoclean' => 0.09,
   'namespace::clean'     => 0.11,
   'overload'             => 1.04,
   'version'              => 0.74,
};

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::Spec::Functions;
use Module::Build;
use SVN::Class ();

sub repository {
   # Accessor for the SVN repository information
   my $file = SVN::Class->svn_dir( q(.) ) or return;
   my $info = $file->info or return;

   return $info->root !~ m{ \A file: }mx ? $info->root : undef;
}

my $class_path = catfile( q(lib), split m{ :: }mx, $MODULE.q(.pm) );
my $distname   = $MODULE; $distname =~ s{ :: }{-}gmx;
my $repository = repository();
my $resources  = { license => $LICENSE, bugtracker => $TRACKER.$distname, };

$resources->{homepage  } = $HOME_PAGE  if ($HOME_PAGE);
$resources->{repository} = $repository if ($repository);

my $builder = Module::Build->new
   ( add_to_cleanup     => [ q(Debian_CPANTS.txt), $distname.q(-*),
                             map { ( q(*/) x $_ ).q(*~) } 0..5 ],
     build_requires     => { 'Exception::Class'    => 1.23,
                             'Test::More'          => 0.74,
                             'Text::Diff'          => 1.37, },
     configure_requires => { 'version'             => 0.74,
                             'ExtUtils::MakeMaker' => 6.42, },
     create_readme      => 1,
     create_packlist    => 0,
     dist_version_from  => $class_path,
     license            => q(perl),
     module_name        => $MODULE,
     no_index           => { directory => [ q(t) ] },
     notes              => { cpan_testers_version => 1 },
     requires           => $REQUIRES,
     resources          => $resources,
     sign               => 1, );

$builder->create_build_script; # Goal

# Local Variables:
# mode: perl
# tab-width: 3
# End:
