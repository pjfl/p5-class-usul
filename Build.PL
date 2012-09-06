# @(#)$Id$

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.8.%d', q$Rev$ =~ /\d+/gmx );

Bob->new( {
   module     => q(Class::Usul),
   home_page  => q(http://www.roxsoft.co.uk),
   requires   => {
      'perl'                          => 5.010,
      'bareword::filehandles'         => 0.003,
      'multidimensional'              => 0.010,
      'namespace::autoclean'          => 0.09,
      'namespace::clean'              => 0.11,
      'parent'                        => 0.221,
      'version'                       => 0.77,
      'Class::Inspector'              => 1.24,
      'Class::Load'                   => 0.18,
      'Class::Null'                   => 1.09,
      'Crypt::CBC'                    => 2.30,
      'Crypt::Twofish'                => 2.12,
      'Data::Printer'                 => 0.24,
      'Date::Format'                  => 2.22,
      'DateTime::Format::Epoch'       => 0.11,
      'Digest::SHA1'                  => 2.11,
      'Email::Date::Format'           => 1.002,
      'File::DataClass'               => q(0.12.0),
      'Getopt::Mixed'                 => 1.10,
      'Git::Class'                    => 0.12,
      'Import::Into'                  => 1.001000,
      'IO::Interactive'               => q(0.0.5),
      'IPC::Cmd'                      => 0.42,
      'IPC::Open3'                    => 1.02,
      'IPC::SRLock'                   => q(0.8.0),
      'Log::Handler'                  => 0.63,
      'Module::Build'                 => 0.38,
      'Module::CoreList'              => 2.24,
      'Module::Load::Conditional'     => 0.26,
      'Module::Pluggable'             => 3.9,
      'Moose'                         => 2.0402,
      'MooseX::AttributeShortcuts'    => 0.014,
      'MooseX::ClassAttribute'        => 0.10,
      'MooseX::MethodAttributes'      => 0.24,
      'MooseX::Role::Parameterized'   => 0.19,
      'MooseX::Role::WithOverloading' => 0.08,
      'MooseX::Traits::Pluggable'     => 0.10,
      'MooseX::Types'                 => 0.25,
      'MooseX::Types::LoadableClass'  => 0.007,
      'POSIX'                         => 1.09,
      'Path::Class'                   => 0.16,
      'Perl::Version'                 => 1.009,
      'Pod::Eventual'                 => 0.093330,
      'Pod::Man'                      => 2.22,
      'Pod::Parser'                   => 1.37,
      'Proc::ProcessTable'            => 0.42,
      'SVN::Class'                    => 0.12,
      'Scalar::Util'                  => 1.19,
      'Sub::Exporter'                 => 0.982,
      'Term::ReadKey'                 => 2.30,
      'Text::Autoformat'              => 1.13,
      'Time::Zone'                    => 2.22,
      'Try::Tiny'                     => 0.09,
      'YAML::Syck'                    => 1.05, },
   recommends            => {
      'App::cpanminus'   => 1.4004, },
   configure_requires    => {
      'version'          => 0.77,
      'Module::Build'    => 0.38, },
   build_requires        => {
      'Class::Null'      => 1.09,
      'Exception::Class' => 1.23,
      'Math::BigInt'     => 1.89,
      'Test::More'       => 0.74, },
} )->create_build_script; # Goal!

# Local Variables:
# mode: perl
# tab-width: 3
# End:
