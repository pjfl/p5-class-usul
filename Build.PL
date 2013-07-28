# @(#)$Ident: Build.PL 2013-07-28 18:21 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.22.%d', q$Rev: 13 $ =~ /\d+/gmx );

Bob->new( {
   module    => 'Class::Usul',
   home_page => 'http://www.roxsoft.co.uk',
   requires  => {
      'perl'                      => 5.010001,
      'namespace::clean'          => 0.23,
      'namespace::sweep'          => 0.006,
      'Class::Inspector'          => 1.24,
      'Class::Load'               => 0.18,
      'Class::Null'               => 2.101420,
      'Crypt::CBC'                => 2.30,
      'Crypt::Twofish2'           => 1.02,
      'Data::Printer'             => 0.35,
      'Data::Record'              => 0.02,
      'Date::Format'              => 2.24,
      'DateTime::Format::Epoch'   => 0.13,
      'Digest::SHA1'              => 2.11,
      'File::DataClass'           => q(0.22.0),
      'File::Gettext'             => q(0.18.0),
      'File::HomeDir'             => 0.93,
      'Getopt::Long::Descriptive' => 0.093,
      'IO::Interactive'           => q(0.0.6),
      'IPC::SRLock'               => q(0.12.0),
      'JSON'                      => 2.50,
      'Log::Handler'              => 0.63,
      'Moo'                       => 1.002,
      'MooX::ClassStash'          => 0.005,
      'MooX::Options'             => 3.83,
      'Path::Class'               => 0.23,
      'Pod::Eventual'             => 0.093330,
      'Regexp::Common'            => 2010010201,
      'Term::ReadKey'             => 2.30,
      'Text::Autoformat'          => 1.669002,
      'Time::Zone'                => 2.24,
      'Try::Tiny'                 => 0.09,
      'Type::Tiny'                => 0.012,
      'Unexpected'                => q(0.4.0),
      'YAML::Syck'                => 1.17, },
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
