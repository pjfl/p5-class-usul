# @(#)$Id$
# Definitions. Change these in case of live use

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.6.%d', q$Rev$ =~ /\d+/gmx );

my $pattern  = 's{ \Q${from}\E \\.%d    }{${to}.%d}gmx; ';
   $pattern .= 's{ \Q${from}\E \\.\$Rev }{${to}.\$Rev}gmx';

Bob->new( {
   sign       => 1,
   stop_tests => 1,
   license    => q(perl),
   module     => q(Your::Class::Name),
   home_page  => q(http://www.example.com),
   bugtracker => q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=),
   requires   => {
      'File::DataClass' => q(0.1.0),
      'IPC::SRLock'     => q(0.3.144),
      'Module::Build'   => 0.35,
      'parent'          => 0.221,
      'perl'            => 5.008,
      'version'         => 0.77, },
   recommends           => { 'CPAN'          => 1.9402, },
   configure_requires   => { 'Class::Usul'   => q(0.1.0),
                             'version'       => 0.77, },
   build_requires       => { 'Test::More'    => 0.74, },
   notes                => { version_pattern => $pattern, },
} )->create_build_script; # Goal!

# Local Variables:
# mode: perl
# tab-width: 3
# End:
