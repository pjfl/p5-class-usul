# @(#)$Id$
# Definitions

my $SIGN      = 1;
my $LICENSE   = q(perl);
my $MODULE    = q(Class::Usul);
my $HOME_PAGE = q(http://www.roxsoft.co.uk);
my $TRACKER   = q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=);
my $REQUIRES  = {
   'Class::MOP'                => '0.94',
   'Class::Null'               => '1.09',
   'Crypt::CBC'                => '2.30',
   'Date::Format'              => '2.22',
   'DateTime::Format::Epoch'   => '0.11',
   'File::DataClass'           => '0.1.0',
   'Getopt::Mixed'             => '1.10',
   'Git::Class'                => '0.03',
   'IO::Interactive'           => '0.0.5',
   'IPC::Cmd'                  => '0.42',
   'IPC::SRLock'               => '0.3.144',
   'Log::Handler'              => '0.63',
   'MRO::Compat'               => '0.11',
   'Module::Build'             => '0.35',
   'Module::CoreList'          => '2.24',
   'Module::Load::Conditional' => '0.26',
   'Module::Pluggable'         => '3.9',
   'Moose'                     => '0.92',
   'MooseX::ClassAttribute'    => '0.10',
   'Path::Class'               => '0.16',
   'Perl::Version'             => '1.009',
   'Pod::Eventual'             => '0.093330',
   'Proc::ProcessTable'        => '0.42',
   'SVN::Class'                => '0.12',
   'Sub::Exporter'             => '0.982',
   'Term::ReadKey'             => '2.30',
   'Text::Autoformat'          => '1.13',
   'Time::Zone'                => '2.22',
   'TryCatch'                  => '1.002000',
   'YAML::Syck'                => '1.05',
   'namespace::autoclean'      => '0.09',
   'namespace::clean'          => '0.11',
   'parent'                    => '0.221',
   'perl'                      => '5.008',
   'version'                   => '0.77',
};
my $RECOMMENDS = { 'CPAN' => '1.9402', };

# Boilerplate

use strict;
use warnings;

use English qw(-no_match_vars);

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

BEGIN {
   eval { require 5.008; }; $EVAL_ERROR and whimper 'Perl minimum 5.8';
}

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
my $resources  = { license => q(http://dev.perl.org/licenses/), };

$HOME_PAGE  and $resources->{homepage  } = $HOME_PAGE;
$TRACKER    and $resources->{bugtracker} = $TRACKER.$distname;

-f q(MANIFEST.SKIP) and $resources->{repository} = repository();

Module::Build->new
   ( add_to_cleanup     => [ q(Debian_CPANTS.txt), $distname.q(-*),
                             map { ( q(*/) x $_ ).q(*~) } 0..5 ],
     build_requires     => { 'Test::More'    => 0.74, },
     configure_requires => { 'Module::Build' => 0.35,
                             'version'       => 0.77, },
     create_readme      => 1,
     create_packlist    => 0,
     dist_version_from  => $class_path,
     license            => $LICENSE,
     module_name        => $MODULE,
     no_index           => { directory => [ q(t) ] },
     recommends         => $RECOMMENDS,
     requires           => $REQUIRES,
     resources          => $resources,
     sign               => $SIGN, )->create_build_script; # Goal

# Local Variables:
# mode: perl
# tab-width: 3
# End:
