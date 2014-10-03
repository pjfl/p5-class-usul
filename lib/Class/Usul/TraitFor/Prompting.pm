package Class::Usul::TraitFor::Prompting;

use namespace::autoclean;

use Class::Usul::Constants qw( BRK FAILED FALSE NO NUL QUIT SPC TRUE YES );
use Class::Usul::Functions qw( arg_list emit_to pad throw );
use Class::Usul::Types     qw( BaseType );
use English                qw( -no_match_vars );
use IO::Interactive;
use Term::ReadKey;
use Moo::Role;

requires qw( add_leader config loc output );

# Public methods
sub anykey {
   my ($self, $prompt) = @_;

   $prompt = $self->_prepare( $prompt || 'Press any key to continue' );

   return __prompt( -p => "${prompt}...", -d => TRUE, -e => NUL, -1 => TRUE );
}

sub get_line { # General text input routine.
   my ($self, $question, $default, $quit, $width, $multiline, $noecho) = @_;

   $question  = $self->_prepare( $question || 'Enter your answer' );
   $default //= NUL;

   my $advice       = $quit ? $self->loc( '([_1] to quit)', QUIT ) : NUL;
   my $right_prompt = $advice.($multiline ? NUL : " [${default}]");
   my $left_prompt  = $question;

   if (defined $width) {
      my $total  = $width || $self->config->pwidth;
      my $left_x = $total - (length $right_prompt);

      $left_prompt = sprintf '%-*s', $left_x, $question;
   }

   my $prompt  = "${left_prompt} ${right_prompt}";
      $prompt .= ($multiline ? "\n[${default}]" : NUL).BRK;
   my $result  = $noecho
               ? __prompt( -d => $default, -p => $prompt, -e => '*' )
               : __prompt( -d => $default, -p => $prompt );

   $quit and defined $result and lc $result eq QUIT and exit FAILED;

   return "${result}";
}

sub get_option { # Select from an numbered list of options
   my ($self, $prompt, $default, $quit, $width, $options) = @_;

   $prompt ||= '+Select one option from the following list:';

   my $no_lead = ('+' eq substr $prompt, 0, 1) ? FALSE : TRUE;
   my $leader  = $no_lead ? NUL : '+'; $prompt =~ s{ \A \+ }{}mx;
   my $max     = @{ $options // [] };

   $self->output( $prompt, { no_lead => $no_lead } ); my $count = 1;

   my $text = join "\n", map { __justify_count( $max, $count++ )." - ${_}" }
                            @{ $options };

   $self->output( $text, { cl => TRUE, nl => TRUE, no_lead => $no_lead } );

   my $question = "${leader}Select option";
   my $opt      = $self->get_line( $question, $default, $quit, $width );

   $opt !~ m{ \A \d+ \z }mx and $opt = $default // 0;

   return $opt - 1;
}

sub is_interactive {
   my $self = shift; return IO::Interactive::is_interactive( @_ );
}

sub yorn { # General yes or no input routine
   my ($self, $question, $default, $quit, $width, $newline) = @_;

   my $no = NO; my $yes = YES; my $result;

   $question = $self->_prepare( $question || 'Choose' );
   $default  = $default ? $yes : $no; $quit = $quit ? QUIT : NUL;

   my $advice       = $quit ? "(${yes}/${no}, ${quit}) " : "(${yes}/${no}) ";
   my $right_prompt = "${advice}[${default}]";
   my $left_prompt  = $question;

   if (defined $width) {
      my $max_width = $width || $self->config->pwidth;
      my $right_x   = length $right_prompt;
      my $left_x    = $max_width - $right_x;

      $left_prompt  = sprintf '%-*s', $left_x, $question;
   }

   my $prompt = "${left_prompt} ${right_prompt}".BRK;

   $newline and $prompt .= "\n";

   while ($result = __prompt( -d => $default, -p => $prompt )) {
      $quit and $result =~ m{ \A (?: $quit | [\e] ) }imx and exit FAILED;
      $result =~ m{ \A $yes }imx and return TRUE;
      $result =~ m{ \A $no  }imx and return FALSE;
   }

   return;
}

# Private methods
sub _prepare {
   my ($self, $question) = @_; my $add_leader;

   '+' eq substr $question, 0, 1 and $add_leader = TRUE
      and $question = substr $question, 1;
   $question = $self->loc( $question );
   $add_leader and $question = $self->add_leader( $question );
   return $question;
}

# Private functions
sub __get_control_chars {
   my $handle = shift; my %cntl = GetControlChars $handle;

   return ((join '|', values %cntl), %cntl);
}

sub __justify_count {
   return pad $_[ 1 ], int log $_[ 0 ] / log 10, SPC, 'left';
}

sub __map_prompt_args { # IO::Prompt equiv. sub has an obscure bug so this
   my $args = shift; my %map = ( qw(-1 onechar -d default -e echo -p prompt) );

   for (grep { exists $map{ $_ } } keys %{ $args }) {
       $args->{ $map{ $_ } } = delete $args->{ $_ };
   }

   return $args;
}

sub __prompt { # Robbed from IO::Prompt
   my $args    = __map_prompt_args( arg_list @_ );
   my $default = $args->{default};
   my $echo    = $args->{echo   };
   my $onechar = $args->{onechar};
   my $OUT     = \*STDOUT;
   my $IN      = \*STDIN;
   my $input   = NUL;

   my ($len, $newlines, $next, $text);

   unless (IO::Interactive::is_interactive()) {
      ($ENV{PERL_MM_USE_DEFAULT} or $ENV{PERL_MB_USE_DEFAULT})
         and return $default;
      $onechar and return getc $IN;
      return scalar <$IN>;
   }

   my ($cntl, %cntl) = __get_control_chars( $IN );
   local $SIG{INT}   = sub { __restore_mode( $IN ); exit FAILED };

   emit_to $OUT, $args->{prompt}; __raw_mode( $IN );

   while (TRUE) {
      if (defined ($next = getc $IN)) {
         if ($next eq $cntl{INTERRUPT}) {
            __restore_mode( $IN ); exit FAILED;
         }
         elsif ($next eq $cntl{ERASE}) {
            if ($len = length $input) {
               $input = substr $input, 0, $len - 1; emit_to( $OUT, "\b \b" );
            }

            next;
         }
         elsif ($next eq $cntl{EOF}) {
            __restore_mode( $IN );
            close $IN or throw 'IO error: [_1]', args =>[ $OS_ERROR ];
            return $input;
         }
         elsif ($next !~ m{ $cntl }mx) {
            $input .= $next;

            if ($next eq "\n") {
               if ($input eq "\n" and defined $default) {
                  $text = defined $echo ? $echo x length $default : $default;
                  emit_to $OUT, "[${text}]\n"; __restore_mode( $IN );

                  return $onechar ? substr $default, 0, 1 : $default;
               }

               $newlines .= "\n";
            }
            else { emit_to $OUT, $echo // $next }
         }
         else { $input .= $next }
      }

      if ($onechar or not defined $next or $input =~ m{ \Q$RS\E \z }mx) {
         chomp $input; __restore_mode( $IN );
         defined $newlines and emit_to $OUT, $newlines;
         return $onechar ? substr $input, 0, 1 : $input;
      }
   }

   return;
}

sub __raw_mode {
   my $handle = shift; ReadMode 'raw', $handle; return;
}

sub __restore_mode {
   my $handle = shift; ReadMode 'restore', $handle; return;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Class::Usul::TraitFor::Prompting - Methods for requesting command line input

=head1 Synopsis

   use Moo;

   with q(Class::Usul::TraitForPrompting);

=head1 Description

Methods that prompt for command line input from the user

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

=head2 anykey

   $key = $self->anykey( $prompt );

Prompt string defaults to 'Press any key to continue...'. Calls and
returns L<prompt|/__prompt>. Requires the user to press any key on the
keyboard (that generates a character response)

=head2 get_line

   $line = $self->get_line( $question, $default, $quit, $width, $newline );

Prompts the user to enter a single line response to C<$question> which
is printed to I<STDOUT> with a program leader. If C<$quit> is true
then the options to quit is included in the prompt. If the C<$width>
argument is defined then the string is formatted to the specified
width which is C<$width> or C<< $self->pwdith >> or 40. If C<$newline>
is true a newline character is appended to the prompt so that the user
get a full line of input

=head2 get_option

   $option = $self->get_option( $question, $default, $quit, $width, $options );

Returns the selected option number from the list of possible options passed
in the C<$question> argument

=head2 is_interactive

   $bool = $self->is_interactive( $optional_filehandle );

Exposes L<IO::Interactive/is_interactive>

=head2 __prompt

   $line = __prompt( 'key' => 'value', ... );

This was taken from L<IO::Prompt> which has an obscure bug in it. Much
simplified the following keys are supported

=over 3

=item -1

Return the first character typed

=item -d

Default response

=item -e

The character to echo in place of the one typed

=item -p

Prompt string

=back

=head2 yorn

   $self->yorn( $question, $default, $quit, $width );

Prompt the user to respond to a yes or no question. The C<$question>
is printed to I<STDOUT> with a program leader. The C<$default>
argument is C<0|1>. If C<$quit> is true then the option to quit is
included in the prompt. If the C<$width> argument is defined then the
string is formatted to the specified width which is C<$width> or
C<< $self->pwdith >> or 40

=head2 __get_control_chars

   ($cntrl, %cntrl) = __get_control_chars( $handle );

Returns a string of pipe separated control characters and a hash of
symbolic names and values

=head2 __raw_mode

   __raw_mode( $handle );

Puts the terminal in raw input mode

=head2 __restore_mode

   __restore_mode( $handle );

Restores line input mode to the terminal

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<IO::Interactive>

=item L<Term::ReadKey>

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

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
