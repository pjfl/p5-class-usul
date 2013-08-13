# @(#)$Id$
# Definitions. Change these in case of live use

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.24.%d', q$Rev: 1 $ =~ /\d+/gmx );

my $pattern  = 's{ \Q${from}\E \\.%d    }{${to}.%d}gmx; ';
   $pattern .= 's{ \Q${from}\E \\.\$Rev }{${to}.\$Rev}gmx';

Bob->new( {
   stop_tests  => 1,
   module      => q(Your::Class::Name),
   home_page   => q(http://www.example.com),
   build_class => q(Class::Usul::Build),
   requires    => {
      'perl'            => 5.010,
      'parent'          => 0.221,
      'version'         => 0.77,
      'File::DataClass' => q(0.8.0),
      'IPC::SRLock'     => q(0.7.0),
      'Module::Build'   => 0.38, },
   recommends           => { 'App::cpanminus' => 1.4004, },
   configure_requires   => { 'version'        => 0.77,
                             'Class::Usul'    => q(0.1.0),
                             'Module::Build'  => 0.38, },
   build_requires       => { 'Test::More'     => 0.74, },
   notes                => { version_pattern  => $pattern, },
} )->create_build_script; # Goal!

# Local Variables:
# mode: perl
# tab-width: 3
# End:
