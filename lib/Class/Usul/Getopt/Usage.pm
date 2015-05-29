package Class::Usul::Getopt::Usage;

use strict;
use warnings;
use parent 'Getopt::Long::Descriptive::Usage';

use List::Util      qw( max );
use Term::ANSIColor qw( color );

my $NUL = q(); my $SPC = q( ); my $TAB = q(   ); my $WIDTH = 78;

my $_option_type = 'verbose';

# Private functions
my $_split_description = sub {
   my ($length, $desc) = @_;
   # 3 for a tab, 2 for the space between option & desc;
   my $max_length = $WIDTH - ( length( $TAB ) + $length + 2 );

   length $desc <= $max_length and return $desc; my @lines;

   while (length $desc > $max_length) {
      my $idx = rindex( substr( $desc, 0, $max_length ), $SPC );

      $idx >= 0 or last;

      push @lines, substr $desc, 0, $idx; substr( $desc, 0, 1 + $idx ) = $NUL;
   }

   push @lines, $desc;
   return @lines;
};

my $_types = sub {
   my $k = shift;

   $_option_type eq 'none'    and return;
   $_option_type eq 'verbose' and return uc $k;

   my $types = { int => 'i', key => 'k', num => 'n', str => 's', };
   my $type  = $types->{ $k } // $NUL;

   return $type;
};

my $_parse_assignment = sub {
   my $assign_spec = shift;

   length $assign_spec < 2 and return $NUL; # Empty, ! or +

   my $argument = substr $assign_spec, 1, 2;
   my $result   = $_types->( 'str' );

   if    ($argument eq 'i' or $argument eq 'o') { $result = $_types->( 'int' ) }
   elsif ($argument eq 'f') { $result = $_types->( 'num' ) }

   if (length $assign_spec > 2) {
      my $desttype = substr $assign_spec, 2, 1;

      # Imply it can be repeated
      if    ($desttype eq '@') { $result .= '...' }
      elsif ($desttype eq '%') {
         $result = $result ? $_types->( 'key' )."=${result}..." : $NUL;
      }
   }

   substr $assign_spec, 0, 1 eq ':' and return "[=${result}]";
   # With leading space so it can just blindly be appended.
   return $result ? " $result" : $NUL;
};

my $_assemble_spec = sub {
   my ($length, $spec) = @_;

   my $stripped = [ Getopt::Long::Descriptive->_strip_assignment( $spec ) ];
   my $assign   = $_parse_assignment->( $stripped->[ 1 ] );
   my $plain    = join $SPC, reverse
                  map    { length > 1 ? "--${_}${assign}" : "-${_}${assign}" }
                  split m{ [|] }mx, $stripped->[ 0 ];
   my $pad      = $SPC x ($length - length $plain);

   $assign = color( 'bold' ).$assign.color( 'reset' );

   my $markedup = join $SPC, reverse
                  map    { length > 1 ? "--${_}${assign}" : "-${_}${assign}" }
                  split m{ [|] }mx, $stripped->[ 0 ];

   return $markedup.$pad;
};

my $_option_length = sub {
   my $fullspec         = shift;
   my $number_opts      = 1;
   my $last_pos         = 0;
   my $number_shortopts = 0;
   my ($spec, $assign)
      = Getopt::Long::Descriptive->_strip_assignment( $fullspec );
   my $length           = length $spec;
   my $arglen           = length $_parse_assignment->( $assign );
   # Spacing rules:
   # For short options we want 1 space (for '-'), for long options 2
   # spaces (for '--').  Then one space for separating the options,
   # but we here abuse that $spec has a '|' char for that.

   # For options that take arguments, we want 2 spaces for mandatory
   # options ('=X') and 4 for optional arguments ('[=X]').  Note we
   # consider {N,M} cases as "single argument" atm.

   # Count the number of "variants" (e.g. "long|s" has two variants)
   while ($spec =~ m{ [|] }gmx) {
      $number_opts++;
      (pos( $spec ) - $last_pos) == 2 and $number_shortopts++;
      $last_pos = pos( $spec );
   }

   # Was the last option a "short" one?
   ($length - $last_pos) == 2 and $number_shortopts++;
   # We got $number_opts options, each with an argument length of
   # $arglen.  Plus each option (after the first) needs 3 a char
   # spacing.  $length gives us the total length of all options and 1
   # char spacing per option (after the first).  It does not account
   # for argument length and we want (at least) one additional char
   # for space before the description.  So the result should be:
   my $number_longopts = $number_opts - $number_shortopts;
   my $total_arglen    = $number_opts * $arglen;
   my $total_optsep    = 2 * $number_longopts + $number_shortopts;
   my $total           = $length + $total_optsep + $total_arglen + 1;
   # Because this looks better than the calculated total
   return $total - 2;
};

# Public methods
sub option_text {
   my $self     = shift;
   my @options  = @{ $self->{options} // [] };
   my @specs    = map { $_->{spec} } grep { $_->{desc} ne 'spacer' } @options;
   my $length   = max( map { $_option_length->( $_ ) } @specs ) || 0;
   my $spec_fmt = "${TAB}%-${length}s";
   my $string   = $NUL;

   while (defined (my $opt = shift @options)) {
      my $spec = $opt->{spec}; my $desc = $opt->{desc};

      if ($desc eq 'spacer') { $string .= sprintf "${spec_fmt}\n", $spec; next }

      if (exists $opt->{constraint}->{default} and $self->{show_defaults}) {
         my $dflt = $opt->{constraint}->{default};
            $dflt = not defined $dflt ? '[undef]'
                  : not length  $dflt ? '[null]'
                                      : $dflt;

         $desc   .= " (default value: ${dflt})";
      }

      my @desc = $_split_description->( $length, $desc );

      $spec    = $_assemble_spec->( $length, $spec );
      $string .= sprintf "${TAB}${spec}  %s\n", shift @desc;

      for my $line (@desc) {
         $string .= $TAB.($SPC x ( $length + 2 ))."${line}\n";
      }
   }

   return $string;
}

sub option_type {
   my ($self, $v) = @_; defined $v and $_option_type = $v; return $_option_type;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Class::Usul::Getopt::Usage - The usage description for Getopt::Long::Descriptive

=head1 Synopsis

   use Class::Usul::Getopt::Usage;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head2 C<option_text>

=head2 C<option_type>

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Usul.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
# vim: expandtab shiftwidth=3:
