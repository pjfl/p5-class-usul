# @(#)$Id$

# Change these definitions in case of live use

my $APPNAME    = q(Class::Usul);
my $HOME_PAGE  = q(http://www.roxsoft.co.uk);
my $LICENSE    = q(perl);
my $LICENSES   = q(http://dev.perl.org/licenses/);
my $TRACKER    = q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=);
my $CONFIGURE  = {
   'version'                   => '0.77',
   'Class::Usul'               => '0.1',
};
my $RECOMMENDS = {
   'CPAN'                      => '1.9402',
};
my $REQUIRES   = {
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
   'XML::Simple'               => '2.18',
   'YAML::Syck'                => '1.05',
   'namespace::autoclean'      => '0.09',
   'namespace::clean'          => '0.11',
   'parent'                    => '0.221',
   'perl'                      => '5.008',
   'version'                   => '0.77',
};

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
     recommands         => $RECOMMENDS,
     requires           => $REQUIRES,
     resources          => $resources, );

$builder->create_build_script; # Goal

exit 0;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
