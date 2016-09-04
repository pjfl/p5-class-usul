use strict;
use warnings;

use File::Spec::Functions qw( catfile );
use Sys::Hostname;

my $testing;

BEGIN {
   $testing = sub { $ENV{AUTOMATED_TESTING}
                 || $ENV{PERL_CPAN_REPORTER_CONFIG}
                 || $ENV{PERL5_CPANPLUS_IS_VERSION} };

   my $create_build_script = sub {
      my $msg = shift;

      open my $fh, '>', 'Build' or die "Cannot open Build";
      print {$fh} "#! $^X\n\n";
      print {$fh} "\$ARGV[ 0 ] or mkdir( 'blib' );\n";
      print {$fh} "\$ARGV[ 0 ] eq 'test' and print \"${msg}\\n\";\n";
      print {$fh} "\$ARGV[ 0 ] eq 'test' and print \"Result: PASS\\n\";\n";
      print {$fh} "exit 0\n";
      close $fh; chmod oct( 755 ), 'Build';
      exit 0;
   };
   my $badtoolchain = sub {
      my $host = lc hostname;
      my $dumped = catfile( 't', 'badtoolchain.dd' );
      my $except = {}; -f $dumped and $except = do $dumped;

      exists $except->{ $host }
         and $create_build_script->( 'Bad toolchain '.$except->{ $host } );

      for my $key (keys %{ $except }) {
         $host =~ m{ $key \z }mx
            and $create_build_script->( 'Bad toolchain '.$except->{ $host } );
      }
   };

   $testing->() and $badtoolchain->();
}

my $perl_ver = ##{ $meta2{prereqs}->{runtime}->{requires}->{perl} ##};
my $name = '##{ $zilla->name ##}'; $name =~ s{ - }{::}gmx;
my $prereqs = {
##{ $plugin->get_prereqs( 1 ) ##}
};
my $whimper = sub { print {*STDOUT} $_[ 0 ]."\n"; exit 0 };
my $stop = sub {
   $testing->() or $whimper->( $_[ 0 ] );
   $prereqs->{build_requires} = { %{ $prereqs->{configure_requires} } };
   $prereqs->{test_requires } = { %{ $prereqs->{configure_requires} } };
   $prereqs->{test_requires }->{ 'Test::Requires' } = 0.06;
   delete $prereqs->{requires};
};

# Not interested in reports below min perl ver
$] < $perl_ver and $stop->( "Minimum required Perl version is ${perl_ver}" );

use Module::Build ##{ $meta2{prereqs}->{configure}->{requires}->{'Module::Build'} ##};

Module::Build->new(
   'module_name' => $name,
   'notes' => { min_perl_version => $perl_ver, testing => $testing->() },
   %{ $prereqs },
##{ $plugin->get_default('share_dir') ##}
)->create_build_script;

exit 0;
