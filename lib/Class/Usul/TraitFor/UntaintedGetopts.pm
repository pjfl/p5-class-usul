# @(#)$Ident: UntaintedGetopts.pm 2013-11-23 11:12 pjf ;

package Class::Usul::TraitFor::UntaintedGetopts;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.33.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( untaint_cmdline );
use Data::Record;
use Encode                  qw( decode );
use Getopt::Long 2.38;
use Getopt::Long::Descriptive 0.091;
use JSON;
use Regexp::Common;
use Scalar::Util            qw( blessed );
use Moo::Role;

my $Extra_Argv = []; my $Usage = "Did we forget new_with_options?\n";

# Construction
sub new_with_options {
   my $self = shift; return $self->new( $self->_parse_options( @_ ) );
}

# Public methods
sub extra_argv {
   return defined $_[ 1 ] ? __extra_argv( $_[ 0 ] )->[ $_[ 1 ] ]
                          : __extra_argv( $_[ 0 ] );
}

sub next_argv {
   return shift @{ __extra_argv( $_[ 0 ] ) };
}

sub options_usage {
   return ucfirst $Usage;
}

sub unshift_argv {
   return unshift @{ __extra_argv( $_[ 0 ] ) }, $_[ 1 ];
}

# Private methods
sub _parse_options {
   my ($self, %args) = @_; my $opt;

   my $class  = blessed $self || $self;
   my %data   = $class->_options_data;
   my %config = $class->_options_config;
   my $enc    = $config{encoding} // 'UTF-8';

   my @skip_options; defined $config{skip_options}
      and @skip_options = @{ $config{skip_options} };

   @skip_options and delete @data{ @skip_options };

   my ($splitters, @options) = __build_options( \%data );

   my @flavour; defined $config{flavour}
      and push @flavour, { getopt_conf => $config{flavour} };

   $config{protect_argv} and local @ARGV = @ARGV;
   $enc and @ARGV = map { decode( $enc, $_ ) } @ARGV;
   $config{no_untaint} or @ARGV = map { untaint_cmdline $_ } @ARGV;
   keys %{ $splitters } and @ARGV = __split_args( $splitters );
   ($opt, $Usage) = describe_options( ('Usage: %c %o'), @options, @flavour );
   $Extra_Argv = [ @ARGV ];

   my ($params, @missing) = __extract_params( \%args, \%config, \%data, $opt );

   if ($config{missing_fatal} and @missing) {
      print join( "\n", (map { "${_} is missing" } @missing), NUL );
      print $Usage, "\n";
      exit FAILED;
   }

   return %{ $params };
}

# Private functions
sub __build_options {
   my $options_data = shift; my $splitters = {}; my @options = ();

   for my $name (sort  { __sort_options( $options_data, $a, $b ) }
                 keys %{ $options_data }) {
      my $option = $options_data->{ $name }; my $doc = $option->{doc};

      not defined $doc and $doc = "No help for ${name}";
      push @options, [ __option_specification( $name, $option ), $doc ];
      defined $option->{autosplit} or next;
      $splitters->{ $name } = Data::Record->new( {
         split => $option->{autosplit}, unless => $RE{quoted} } );
      $option->{short}
         and $splitters->{ $option->{short} } = $splitters->{ $name };
   }

   return ($splitters, @options);
}

sub __extra_argv {
   return $_[ 0 ]->{_extra_argv} //= [ @{ $Extra_Argv } ];
}

sub __extract_params {
   my ($args, $config, $options_data, $cmdline_opt) = @_;

   my $params = { %{ $args } }; my $prefer = $config->{prefer_commandline};

   my @missing_required;

   for my $name (keys %{ $options_data }) {
      my $option = $options_data->{ $name };

      if ($prefer or not defined $params->{ $name }) {
         my $val; defined ($val = $cmdline_opt->$name()) and
            $params->{ $name } = $option->{json} ? decode_json( $val ) : $val;
      }

      $option->{required} and not defined $params->{ $name }
         and push @missing_required, $name;
   }

   return ($params, @missing_required);
}

sub __option_specification {
   my ($name, $opt) = @_;

   my $dash_name   = $name; $dash_name =~ tr/_/-/; # Dash name support
   my $option_spec = $dash_name;

   defined $opt->{short} and $option_spec .= '|'.$opt->{short};
   $opt->{repeatable} and not defined $opt->{format} and $option_spec .= '+';
   $opt->{negateable} and $option_spec .= '!';
   defined $opt->{format} and $option_spec .= '='.$opt->{format};
   return $option_spec;
}

sub __split_args {
   my $splitters = shift; my @new_argv;

   for (my $i = 0, my $nargvs = @ARGV; $i < $nargvs; $i++) { # Parse all argv
      my $arg = $ARGV[ $i ];

      my ($name, $value) = split m{ [=] }mx, $arg, 2; $name =~ s{ \A --? }{}mx;

      if (my $splitter = $splitters->{ $name }) {
         $value //= $ARGV[ ++$i ];

         for my $subval (map { s{ \A [\'\"] | [\'\"] \z }{}gmx; $_ }
                         $splitter->records( $value )) {
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

1;

__END__

=pod

=head1 Name

Class::Usul::TraitFor::UntaintedGetopts - Untaints @ARGV before Getopts processes it

=head1 Version

This documents version v0.33.$Rev: 1 $

=head1 Synopsis

   use Moo;

   with 'Class::Usul::TraitFor::UntaintedGetopts';

=head1 Description

Untaints C<@ARGV> before Getopts processes it. Replaces L<MooX::Options>
with an implementation closer to L<MooseX::Getopt::Dashes>

=head1 Configuration and Environment

Modifies C<new_with_options> and C<options_usage>

=head1 Subroutines/Methods

=head2 extra_argv

Returns an array ref containing the remaining command line arguments

=head2 new_with_options

Parses the command line options and then calls the constructor

=head2 next_argv

Returns the next value from L</extra_argv> shifting the value off the list

=head2 options_usage

Returns the options usage string

=head2 _parse_options

Untaints the values of the C<@ARGV> array before the are parsed by
L<Getopt::Long::Descriptive>

=head2 unshift_argv

Pushes the supplied argument back onto the C<extra_argv> list

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Data::Record>

=item L<Encode>

=item L<Getopt::Long>

=item L<Getopt::Long::Descriptive>

=item L<JSON>

=item L<Moo::Role>

=item L<Regexp::Common>

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
