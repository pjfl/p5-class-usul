use strict;
use warnings;

use Module::Build 0.4004;

sub testing { $ENV{AUTOMATED_TESTING} || $ENV{PERL_CPAN_REPORTER_CONFIG}
                                      || $ENV{PERL5_CPANPLUS_IS_VERSION} }
sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

my $perl_ver = 5.010001;
my $name     = 'Class-Usul'; $name =~ s{ - }{::}gmx;
my $prereqs  = {
  'build_requires' => {
    'Capture::Tiny' => '0.22',
    'Hash::MoreUtils' => '0.05',
    'Module::Build' => '0.4004',
    'Test::Deep' => '0.108',
    'Test::Requires' => '0.06',
    'version' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'recommends' => {
    'IPC::Run' => '0.89',
    'Proc::ProcessTable' => '0.42'
  },
  'requires' => {
    'Class::Inspector' => '1.28',
    'Class::Null' => '2.110730',
    'Crypt::CBC' => '2.33',
    'Crypt::Twofish2' => '1.02',
    'Data::Printer' => '0.35',
    'Data::Record' => '0.02',
    'Date::Format' => '2.24',
    'DateTime::Format::Epoch' => '0.13',
    'Exporter::Tiny' => '0.042',
    'File::DataClass' => 'v0.62.0',
    'File::Gettext' => 'v0.27.0',
    'File::HomeDir' => '1.0',
    'Getopt::Long::Descriptive' => '0.097',
    'IO::Interactive' => 'v0.0.6',
    'IPC::SRLock' => 'v0.26.0',
    'JSON::MaybeXS' => '1.002002',
    'Log::Handler' => '0.82',
    'Module::Runtime' => '0.014',
    'Moo' => '2.000001',
    'Pod::Eventual' => '0.094001',
    'Regexp::Common' => '2013031301',
    'Sub::Install' => '0.928',
    'Term::ReadKey' => '2.32',
    'Text::Autoformat' => '1.669002',
    'Time::Zone' => '2.24',
    'Try::Tiny' => '0.22',
    'Type::Tiny' => '1.000002',
    'Unexpected' => 'v0.38.0',
    'namespace::autoclean' => '0.22',
    'namespace::clean' => '0.25',
    'perl' => '5.010001'
  },
};

if ($] < $perl_ver) { # Not interested in reports below min perl ver
   testing or whimper "Minimum required Perl version is ${perl_ver}";
   $prereqs->{build_requires} = { %{ $prereqs->{configure_requires} } };
   $prereqs->{build_requires}->{ 'Test::Requires' } = 0.06;
   delete $prereqs->{requires};
}

Module::Build->new(
   'module_name' => $name,
   'notes'       => { min_perl_version => $perl_ver, testing => testing },
   %{ $prereqs },

)->create_build_script;

exit 0;
