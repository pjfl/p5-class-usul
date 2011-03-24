# @(#)$Id$

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.6.%d', q$Rev$ =~ /\d+/gmx );

Bob->new( {
   stop_tests => 1,
   license    => q(perl),
   module     => q(Class::Usul),
   home_page  => q(http://www.roxsoft.co.uk),
   requires   => {
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
      'version'                   => '0.77', },
   recommends         => { 'CPAN'          => 1.9402, },
   configure_requires => { 'Module::Build' => 0.35,
                           'version'       => 0.77, },
   build_requires     => { 'Test::More'    => 0.74, },
} )->create_build_script; # Goal!

# Local Variables:
# mode: perl
# tab-width: 3
# End:
