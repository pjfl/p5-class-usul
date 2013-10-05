# @(#)$Ident: UntaintedGetopts.pm 2013-10-02 18:31 pjf ;

package Class::Usul::TraitFor::UntaintedGetopts;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.31.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( untaint_cmdline );
use Data::Record;
use Encode                  qw( decode );
use Getopt::Long 2.38;
use Getopt::Long::Descriptive 0.091;
use JSON;
use Regexp::Common;
use Moo::Role;

my ($Extra_Argv, $Usage) = ([], NUL);

# Construction
around 'options_usage' => sub {
   return $Usage;
};

around 'parse_options' => sub {
   my ($orig, $class, %args) = @_;

   my %options_data   = $class->_options_data;
   my %options_config = $class->_options_config;
   my $option_name    = sub {
      my ($name, %data) = @_;

      my $dash_name    = $name; $dash_name =~ tr/_/-/; # Dash name support
      my $cmdline_name = $dash_name;

      defined $data{short} and $cmdline_name .= '|'.$data{short};

      $data{repeatable } and not defined $data{format} and $cmdline_name .= '+';
      $data{negativable} and $cmdline_name .= '!';
      defined $data{format} and $cmdline_name .= '='.$data{format};
      return $cmdline_name;
   };

   my (%has_to_split, @options, @skip_options);

   defined $options_config{skip_options}
      and @skip_options = @{ $options_config{skip_options} };

   @skip_options and delete @options_data{ @skip_options };

   for my $name (sort { __sort_options( \%options_data, $a, $b ) }
                 keys %options_data ) {
      my %data = %{ $options_data{ $name } }; my $doc = $data{doc};

      not defined $doc and $doc = "No help for ${name}";
      push @options, [ $option_name->( $name, %data ), $doc ];
      defined $data{autosplit} and $has_to_split{ $name } = Data::Record->new( {
         split => $data{autosplit}, unless => $RE{quoted} } );
   }

   $options_config{protect_argv} and local @ARGV = @ARGV;

   my $enc; $enc = $options_config{encoding} // 'UTF-8'
      and @ARGV = map { decode( $enc, $_ ) } @ARGV;

   @ARGV = map { untaint_cmdline $_ } @ARGV;

   %has_to_split and @ARGV = __split_args( \%has_to_split );

   my (@flavour, $opt);

   defined $options_config{flavour}
      and push @flavour, { getopt_conf => $options_config{flavour} };

   ($opt, $Usage) = describe_options( ("Usage: %c %o"), @options, @flavour );

   push @{ $Extra_Argv }, $_ for (@ARGV);

   my %cmdline_params = %args; my @missing_required;
   # Make that config option tri-state and ignore the default of false
   my $prefer_cmdline = __tri2bool( $options_config{prefer_commandline} );

   for my $name (keys %options_data) {
      my %data = %{ $options_data{ $name } };

      if ($prefer_cmdline or not defined $cmdline_params{ $name }) {
         my $val; defined ($val = $opt->$name()) and
            $cmdline_params{ $name } = $data{json} ? decode_json( $val ) : $val;
      }

      $data{required} and not defined $cmdline_params{ $name }
         and push @missing_required, $name;
   }

   if ($options_config{missing_fatal} and @missing_required) {
      print join( "\n", (map { $_.' is missing' } @missing_required), NUL );
      print $Usage, "\n";
      exit FAILED;
   }

   return %cmdline_params;
};

# Public methods
sub extra_argv {
   return defined $_[ 1 ] ? __extra_argv( $_[ 0 ] )->[ $_[ 1 ] ]
                          : __extra_argv( $_[ 0 ] );
}

sub next_argv {
   return shift @{ __extra_argv( $_[ 0 ] ) };
}

# Private functions
sub __extra_argv {
   return $_[ 0 ]->{_extra_argv} //= [ @{ $Extra_Argv } ];
}

sub __split_args {
   my $args = shift; my @new_argv;

   for my $i (0 .. $#ARGV) { # Parse all argv
      my $arg = $ARGV[ $i ]; my ($name, $value) = split m{ [=] }mx, $arg, 2;

      $name =~ s{ \A --? }{}mx; $value //= $ARGV[ ++$i ];

      if (my $splitter = $args->{ $name }) {
         for my $subval ($splitter->records( $value )) {
            # Remove the quoted if exist to chain
            $subval =~ s{ \A [\'\"] | [\'\"] \z }{}gmx;
            push @new_argv, "--${name}", $subval;
         }
      }
      else { push @new_argv, $arg }
   }

   return @new_argv;
}

sub __sort_options {
   my ($opts, $a, $b) = @_; my $max = 999;

   my $oa = $opts->{ $a }{order} || $max; my $ob = $opts->{ $b }{order} || $max;

   return ($oa == $max) && ($ob == $max) ? $a cmp $b : $oa <=> $ob;
}

sub __tri2bool {
   return $_[ 0 ] == -1 ? FALSE : TRUE;
}

1;

__END__

=pod

=head1 Name

Class::Usul::TraitFor::UntaintedGetopts - Untaints @ARGV before Getopts processes it

=head1 Version

This documents version v0.31.$Rev: 1 $

=head1 Synopsis

   use Moo;

   with 'Class::Usul::TraitFor::UntaintedGetopts';

=head1 Description

Untaints @ARGV before Getopts processes it

=head1 Subroutines/Methods

=head2 extra_argv

Returns an array ref containing the remaining command line arguments

=head2 next_argv

Returns the next value from L</extra_argv> shifting the value off the list

=head2 parse_options

Modifies this method in L<MooX::Options::Base>. Untaints the values of the
I<@ARGV> array before the are parsed by L<Getopt::Long>

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo::Role>

=item L<MooX::Options>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
