# @(#)$Ident: Build.PL 2013-05-16 10:49 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.21.%d', q$Rev: 3 $ =~ /\d+/gmx );

Bob->new( {
   module    => q(Class::Usul),
   home_page => q(http://www.roxsoft.co.uk),
   requires  => {
      'perl'                          => 5.01,
      'namespace::autoclean'          => 0.13,
      'namespace::clean'              => 0.23,
      'Class::Inspector'              => 1.24,
      'Class::Load'                   => 0.18,
      'Class::Null'                   => 2.101420,
      'Crypt::CBC'                    => 2.30,
      'Crypt::Twofish2'               => 1.02,
      'Data::Printer'                 => 0.24,
      'Date::Format'                  => 2.24,
      'DateTime::Format::Epoch'       => 0.13,
      'Digest::SHA1'                  => 2.11,
      'File::DataClass'               => q(0.20.10),
      'File::Gettext'                 => q(0.16.0),
      'File::HomeDir'                 => 0.93,
      'Import::Into'                  => 1.001000,
      'IO::Interactive'               => q(0.0.6),
      'IPC::SRLock'                   => q(0.11.11),
      'Log::Handler'                  => 0.63,
      'Moose'                         => 2.0802,
      'MooseX::Aliases'               => 0.10,
      'MooseX::AttributeShortcuts'    => 0.014,
      'MooseX::ClassAttribute'        => 0.27,
      'MooseX::Getopt'                => 0.56,
      'MooseX::MethodAttributes'      => 0.24,
      'MooseX::Types'                 => 0.35,
      'MooseX::Types::Common'         => 0.001008,
      'MooseX::Types::LoadableClass'  => 0.008,
      'Path::Class'                   => 0.23,
      'Sub::Exporter'                 => 0.982,
      'Sub::Exporter::Progressive'    => 0.001006,
      'Term::ReadKey'                 => 2.30,
      'Text::Autoformat'              => 1.669002,
      'Time::Zone'                    => 2.24,
      'Try::Tiny'                     => 0.09,
      'Unexpected'                    => q(0.1.0),
      'YAML::Syck'                    => 1.17, },
   recommends              => {
      'App::cpanminus'     => 1.6005,
      'Proc::ProcessTable' => 0.42, },
   configure_requires      => {
      'version'            => 0.88,
      'Module::Build'      => 0.4004, },
   build_requires          => {
      'version'            => 0.88,
      'Module::Build'      => 0.4004,
      'Test::Deep'         => 0.108, },
} )->create_build_script; # Goal!

# Local Variables:
# tab-title: Class::Usul
# eval: (load-project-state "class-usul")
# mode: perl
# tab-width: 3
# End:
