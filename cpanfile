requires "Class::Inspector" => "1.28";
requires "Class::Null" => "2.110730";
requires "Crypt::CBC" => "2.33";
requires "Crypt::Twofish2" => "1.02";
requires "Data::Printer" => "0.36";
requires "Data::Record" => "0.02";
requires "Date::Format" => "2.24";
requires "DateTime::Format::Epoch" => "0.13";
requires "Exporter::Tiny" => "0.042";
requires "File::DataClass" => "v0.66.0";
requires "File::Gettext" => "v0.29.0";
requires "File::HomeDir" => "1.0";
requires "File::Which" => "1.18";
requires "Getopt::Long::Descriptive" => "0.099";
requires "IO::Interactive" => "v0.0.6";
requires "IPC::SRLock" => "v0.26.0";
requires "JSON::MaybeXS" => "1.003";
requires "Log::Handler" => "0.82";
requires "Module::Runtime" => "0.014";
requires "Moo" => "2.000001";
requires "Pod::Eventual" => "0.094001";
requires "Regexp::Common" => "2013031301";
requires "Sub::Install" => "0.928";
requires "Term::ReadKey" => "2.32";
requires "Text::Autoformat" => "1.72";
requires "Time::Zone" => "2.24";
requires "Try::Tiny" => "0.22";
requires "Type::Tiny" => "1.000002";
requires "Unexpected" => "v0.39.0";
requires "namespace::autoclean" => "0.26";
requires "namespace::clean" => "0.25";
requires "perl" => "5.010001";
recommends "IPC::Run" => "0.89";
recommends "Proc::ProcessTable" => "0.42";

on 'build' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};

on 'test' => sub {
  requires "Capture::Tiny" => "0.22";
  requires "File::Spec" => "0";
  requires "Hash::MoreUtils" => "0.05";
  requires "Module::Build" => "0.4004";
  requires "Module::Metadata" => "0";
  requires "Sys::Hostname" => "0";
  requires "Test::Deep" => "0.108";
  requires "Test::Requires" => "0.06";
  requires "version" => "0.88";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};
