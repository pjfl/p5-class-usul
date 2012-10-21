# @(#)$Id$

package Class::Usul::Programs;

use strict;
use attributes ();
use version; our $VERSION = qv( sprintf '0.8.%d', q$Rev$ =~ /\d+/gmx );

use Class::Inspector;
use Class::Usul::IPC;
use Class::Usul::File;
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Response::Meta;
use Class::Usul::Functions qw(abs_path app_prefix arg_list assert_directory
                              class2appdir classdir elapsed env_prefix
                              exception find_source is_arrayref is_hashref
                              is_member prefix2class say throw
                              untaint_identifier untaint_path);
use Encode                 qw(decode);
use English                qw(-no_match_vars);
use File::Spec::Functions  qw(catdir catfile);
use IO::Interactive        qw(is_interactive);
use List::Util             qw(first);
use Config;
use Pod::Man;
use Pod::Usage;
use File::HomeDir;
use Term::ReadKey;
use Text::Autoformat;
use Try::Tiny;

extends q(Class::Usul);
with    q(MooseX::Getopt::Dashes);
with    q(Class::Usul::TraitFor::LoadingClasses);
with    q(Class::Usul::TraitFor::UntaintedGetopts);

has '+config_class' => default => 'Class::Usul::Config::Programs';

has '+debug'        => traits => [ 'Getopt' ], cmd_aliases => q(D),
   cmd_flag         => 'debug';


has 'help_options' => is => 'ro', isa => Bool, default => FALSE,
   documentation   => 'Uses Pod::Usage to describe the program usage options',
   traits          => [ 'Getopt' ], cmd_aliases => q(h), cmd_flag => 'help_opt';

has 'help_manual'  => is => 'ro', isa => Bool, default => FALSE,
   documentation   => 'Uses Pod::Man to display the program documentation',
   traits          => [ 'Getopt' ], cmd_aliases => q(H), cmd_flag => 'man_page';

has 'home'         => is => 'ro', isa => SimpleStr,
   documentation   => 'Directory containing the configuration file',
   traits          => [ 'Getopt' ], cmd_flag => 'home';

has 'language'     => is => 'ro', isa => SimpleStr,  default => NUL,
   documentation   => 'Loads the specified language message catalog',
   traits          => [ 'Getopt' ], cmd_aliases => q(L), cmd_flag => 'language';

has 'method'       => is => 'rw', isa => SimpleStr | Undef,  default => NUL,
   documentation   => 'Name of the method to call. Required',
   traits          => [ 'Getopt' ], cmd_aliases => q(c), cmd_flag => 'command';

has 'nodebug'      => is => 'ro', isa => Bool, default => FALSE,
   documentation   => 'Do not prompt for debugging',
   traits          => [ 'Getopt' ], cmd_aliases => q(n), cmd_flag => 'nodebug';

has 'options'      => is => 'ro', isa => HashRef, default => sub { {} },
   documentation   =>
      'Zero, one or more key/value pairs available to the method call',
   traits          => [ 'Getopt' ], cmd_aliases => q(o), cmd_flag => 'option';

has 'quiet'        => is => 'ro', isa => Bool, default => FALSE,
   documentation   => 'Quiet the display of information messages',
   traits          => [ 'Getopt' ], cmd_aliases => q(q), cmd_flag => 'quiet';

has 'version'      => is => 'ro', isa => Bool, default => FALSE,
   documentation   => 'Displays the version number of the program class',
   traits          => [ 'Getopt' ], cmd_aliases => q(V), cmd_flag => 'version';


has '_file'    => is => 'lazy', isa => FileType,
   default     => sub { Class::Usul::File->new( builder => $_[ 0 ] ) },
   handles     => [ qw(io) ], init_arg => undef, reader => 'file';

has '_ipc'     => is => 'lazy', isa => IPCType,
   default     => sub { Class::Usul::IPC->new( builder => $_[ 0 ] ) },
   handles     => [ qw(run_cmd) ], init_arg => undef, reader => 'ipc';

has '_logname' => is => 'lazy', isa => NonEmptySimpleStr,
   default     => sub { untaint_identifier( $ENV{USER} || $ENV{LOGNAME} ) },
   init_arg    => undef, reader => 'logname';

has '_mode'    => is => 'rw',   isa => PositiveInt, accessor => 'mode',
   default     => sub { $_[ 0 ]->config->mode }, init_arg => 'mode',
   lazy        => TRUE;

has '_os'      => is => 'lazy', isa => HashRef, init_arg => undef,
   reader      => 'os';

has '_params'  => is => 'ro',   isa => HashRef, default => sub { {} },
   init_arg    => 'params', reader => 'params';

has '_pwidth'  => is => 'rw',   isa => PositiveInt, accessor => 'pwidth',
   default     => 60, init_arg => 'pwidth';

around 'BUILDARGS' => sub {
   my ($next, $class, @args) = @_; my $attr = $class->$next( @args );

   my $cfg = $attr->{config} ||= {};

   $cfg->{appclass} ||= delete $attr->{appclass} || prefix2class $PROGRAM_NAME;
   $cfg->{home    } ||= __get_homedir ( $cfg->{appclass}, $attr->{home} );
   $cfg->{cfgfiles} ||= __get_cfgfiles( $cfg->{appclass},  $cfg->{home} );

   return $attr;
};

sub BUILD {
   my $self = shift; $self->_apply_encoding;

   $self->help_flag    and $self->_output_usage( 0 );
   $self->help_options and $self->_output_usage( 1 );
   $self->help_manual  and $self->_output_usage( 2 );
   $self->version      and $self->_output_version;

   $self->debug( $self->_get_debug_option );
   return;
}

sub add_leader {
   my ($self, $text, $args) = @_; $args ||= {};

   $text = $self->loc( $text || '[no message]', $args->{args} || [] );

   my $leader = exists $args->{no_lead}
              ? NUL : (ucfirst $self->config->name).BRK;

   if ($args->{fill}) {
      my $width = $args->{width} || WIDTH;

      $text = autoformat $text, { right => $width - 1 - length $leader };
   }

   return join "\n", map { (m{ \A $leader }mx ? NUL : $leader).$_ }
                     split  m{ \n }mx, $text;
}

sub anykey {
   my $prompt = $_[ 1 ] || 'Press any key to continue...';

   return __prompt( -p => $prompt, -e => NUL, -1 => TRUE );
}

sub can_call {
   return (is_member $_[ 1 ], __list_methods_of( $_[ 0 ] )) ? TRUE : FALSE;
}

sub debug_flag {
   return $_[ 0 ]->debug ? q(-D) : q(-n);
}

sub dump_self : method {
   my $self = shift;

   $self->dumper( $self ); $self->dumper( $self->config );
   return OK;
}

sub error {
   my ($self, $err, $args) = @_;

   $self->log->error( $_ ) for (split m{ \n }mx, NUL.$err);

   __print_fh( \*STDERR, $self->add_leader( $err, $args )."\n" );
   return;
}

sub fatal {
   my ($self, $err, $args) = @_; my (undef, $file, $line) = caller 0;

   $err ||= 'unknown'; my $posn = ' at '.abs_path( $file )." line ${line}";

   $self->log->alert( $_ ) for (split m{ \n }mx, $err.$posn);

   __print_fh( \*STDERR, $self->add_leader( $err, $args ).$posn."\n" );

   $err and blessed $err
        and $err->can( q(stacktrace) )
        and __print_fh( \*STDERR, $err->stacktrace."\n" );

   exit FAILED;
}

sub get_line { # General text input routine.
   my ($self, $question, $default, $quit, $width, $multiline, $noecho) = @_;

   $question ||= 'Enter your answer'; $default = $default // NUL;

   my $advice       = $quit ? '('.QUIT.' to quit)' : NUL;
   my $right_prompt = $advice.($multiline ? NUL : " [${default}]");
   my $left_prompt  = $question;

   if (defined $width) {
      my $total  = $width || $self->pwidth;
      my $left_x = $total - (length $right_prompt);

      $left_prompt = sprintf '%-*s', $left_x, $question;
   }

   my $prompt  = $left_prompt.SPC.$right_prompt;
      $prompt .= ($multiline ? "\n".q([).$default.q(]) : NUL).BRK;
   my $result  = $noecho
               ? __prompt( -d => $default, -p => $prompt, -e => q(*) )
               : __prompt( -d => $default, -p => $prompt );

   $quit and defined $result and lc $result eq QUIT and exit FAILED;

   return NUL.$result;
}

sub get_meta {
   my ($self, $path) = @_; my $meta_class = q(Class::Usul::Response::Meta);

   my @paths = ( $self->config->appldir->catfile( q(META.yml) ),
                 $self->config->ctrldir->catfile( q(META.yml) ),
                 $self->io( q(META.yml) ) );

   $path and unshift @paths, $self->io( $path );

   return $meta_class->new( $_ ) for (grep { $_->is_file } @paths);

   throw 'No META.yml file';
   return;
}

sub get_option {
   my ($self, $question, $default, $quit, $width, $options) = @_;

   $question ||= 'Select one option from the following list:';

   $self->output( $question, { cl => TRUE } ); my $count = 1;

   my $text = join "\n", map { $count++.q( - ).$_ } @{ $options };

   $self->output( $text, { cl => TRUE, nl => TRUE } );

   my $opt = $self->get_line( 'Select option', $default, $quit, $width );

   $opt !~ m{ \A \d+ \z }mx and $opt = $default // 0;

   return $opt - 1;
}

sub info {
   my ($self, $msg, $args) = @_;

   $self->log->info( $_ ) for (split m{ [\n] }mx, $msg);

   $self->quiet or say $self->add_leader( $msg, $args );
   return;
}

sub interpolate_cmd {
   my ($self, $cmd, @args) = @_;

   my $ref = $self->can( q(_interpolate_).$cmd.q(_cmd) )
      or return [ $cmd, @args ];

   return $self->$ref( $cmd, @args );
}

sub list_methods : method {
   say __list_methods_of( shift ); return OK;
}

sub loc {
   my ($self, $key, @args) = @_; my $car = $args[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @args ] };

   $args->{domain_names} ||= [ DEFAULT_L10N_DOMAIN, $self->config->name ];
   $args->{locale      } ||= $self->language;

   return $self->localize( $key, $args );
}

sub output {
   my ($self, $text, $args) = @_; $args ||= {};

   $self->quiet and return; $args->{cl} and say;

   say $self->add_leader( $text, $args ); $args->{nl} and say;

   return;
}

sub run {
   my $self = shift; my ($rv, $text);

   my $method = $self->method or $self->_output_usage( 0 );

   $text  = 'Started by '.$self->logname.' Version '.$self->VERSION.SPC;
   $text .= 'Pid '.(abs $PID);
   $self->output( $text );

   if ($self->can( $method ) and $self->can_call( $method )) {
      umask $self->mode;

      my $params = exists $self->params->{ $method }
                 ? $self->params->{ $method } : [];

      try { defined ($rv = $self->$method( @{ $params } ))
               or throw error => 'Method [_1] return value undefined',
                        args  => [ $method ];
      }
      catch {
         my $e = exception $_;

         $e->out and $self->output( $e->out );
         $self->error( $e->error, { args => $e->args } );
         $self->debug and __print_fh( \*STDERR, $e->stacktrace."\n" );
         $rv = $e->rv || -1;
      };

      not defined $rv and $rv = -1
         and $self->error( "Method ${method} error uncaught/rv undefined" );
   }
   else {
      $self->error( "Method ${method} not defined in class ".(blessed $self) );
      $rv = -1;
   }

   if (defined $rv and not $rv) {
      $self->output( 'Finished in '.elapsed.' seconds' );
   }
   elsif (defined $rv) { $self->output( "Terminated code ${rv}" ) }
   else { $self->output( 'Terminated with undefined rv' ); $rv = FAILED }

   $self->file->delete_tmp_files;
   return $rv || OK;
}

sub warning {
   my ($self, $err, $args) = @_;

   $self->log->warn( $_ ) for (split m{ \n }mx, $err);

   $self->quiet or say $self->add_leader( $err, $args );
   return;
}

sub yorn { # General yes or no input routine
   my ($self, $question, $default, $quit, $width, $newline) = @_;

   my $no = NO; my $yes = YES; my $result;

   $default = $default ? $yes : $no; $quit = $quit ? QUIT : NUL;

   my $advice       = $quit ? "(${yes}/${no}, ${quit}) " : "(${yes}/${no}) ";
   my $right_prompt = "${advice}[${default}]";
   my $left_prompt  = $question;

   if (defined $width) {
      my $max_width = $width || $self->pwidth;
      my $right_x   = length $right_prompt;
      my $left_x    = $max_width - $right_x;

      $left_prompt  = sprintf '%-*s', $left_x, $question;
   }

   my $prompt = $left_prompt.SPC.$right_prompt.BRK;

   $newline and $prompt .= "\n";

   while ($result = __prompt( -d => $default, -p => $prompt )) {
      $quit and $result =~ m{ \A (?: $quit | [\e] ) }imx and exit FAILED;
      $result =~ m{ \A $yes }imx and return TRUE;
      $result =~ m{ \A $no  }imx and return FALSE;
   }

   return;
}

# Private methods

sub _apply_encoding {
   my $self = shift; my $enc = $self->encoding;

   autoflush STDOUT TRUE; autoflush STDERR TRUE;

   binmode $_, ":encoding(${enc})" for (*STDIN, *STDOUT, *STDERR);

   $_ = decode( $enc , $_ ) for @ARGV;

   return;
}

sub _build__os {
   my $self = shift;
   my $file = q(os_).$Config{osname}.$self->config->extension;
   my $path = $self->config->ctrldir->catfile( $file );

   $path->exists or return {};

   my $cfg  = $self->file->data_load( arrays => [ q(os) ], paths => [ $path ] );

   return $cfg->{os} || {};
}

sub _dont_ask {
   return $_[ 0 ]->debug || $_[ 0 ]->help_flag || $_[ 0 ]->help_options
       || $_[ 0 ]->help_manual || ! is_interactive();
}

sub _getopt_full_usage { # Required to stop MX::Getopt from printing usage
}

sub _get_debug_option {
   my $self = shift;

   $self->nodebug   and return FALSE;
   $self->_dont_ask and return $self->debug;

   return $self->yorn( 'Do you want debugging turned on', FALSE, TRUE );
}

sub _man_page_from {
   my ($self, $src) = @_; my $cfg = $self->config;

   my $parser   = Pod::Man->new( center  => $cfg->doc_title || NUL,
                                 name    => $cfg->script,
                                 release => 'Version '.$self->VERSION,
                                 section => q(3m) );
   my $tempfile = $self->file->tempfile;
   my $cmd      = $cfg->man_page_cmd || [];

   $parser->parse_from_file( NUL.$src->pathname, $tempfile->pathname );
   say $self->run_cmd( [ @{ $cmd }, $tempfile->pathname ] )->out;
   return OK;
}

sub _output_usage {
   my ($self, $verbose) = @_;

   my $method = $self->extra_argv ? $self->extra_argv->[ 0 ] : undef;

   $method and $self->can_call( $method ) and exit $self->_usage_for( $method );

   $verbose > 1 and exit $self->_man_page_from( $self->config );

   if ($verbose > 0) {
      pod2usage( { -input   => NUL.$self->config->pathname, -message => SPC,
                   -verbose => $verbose } ); # Never returns
   }

   warn ucfirst $self->usage;
   exit OK;
}

sub _output_version {
   $_[ 0 ]->output( 'Version '.$_[ 0 ]->VERSION ); exit OK;
}

sub _usage_for {
   my ($self, $method) = @_; my @classes = (blessed $self);

   $method = untaint_identifier $method;

   while (my $class = shift @classes) {
      no strict q(refs);

      if (defined &{ "${class}::${method}" }) {
         my $selector = Pod::Select->new(); $selector->select( "/${method}" );
         my $tempfile = $self->file->tempfile;

         $selector->parse_from_file( find_source $class, $tempfile->pathname );
         return $self->_man_page_from( $tempfile );
      }

      push @classes, $_ for (@{ "${class}::ISA" });
   }

   return FAILED;
}

# Private functions

sub __get_cfgfiles {
   my ($appclass, $home) = @_;

   my $prefix = app_prefix $appclass; my $files = []; my $file;

   for my $extn (keys %{ Class::Usul::File->extensions }) {
      $file = untaint_path catfile( $home, "${prefix}${extn}" );
      -f $file and push @{ $files }, $file;
      $file = untaint_path catfile( $home, "${prefix}_local${extn}" );
      -f $file and push @{ $files }, $file;
   }

   return $files;
}

sub __get_control_chars {
   my $handle = shift; my %cntl = GetControlChars $handle;

   return ((join q(|), values %cntl), %cntl);
}

sub __get_homedir {
   my ($appclass, $home) = @_; my ($file, $path);

   # 0. Pass the directory in
   $path = assert_directory $home and return $path;

   # 1. Environment variable
   $path = $ENV{ (env_prefix $appclass).q(_HOME) };
   $path = assert_directory $path and return $path;

   my $appdir   = class2appdir $appclass;
   my $classdir = classdir     $appclass;
   my $prefix   = app_prefix   $appclass;

   # 2a. Users home directory - contains application directory
   $path = catdir( File::HomeDir->my_home, $appdir );
   $path = catdir( $path, qw(default lib), $classdir );
   $path = assert_directory $path and return $path;

   # 2b. Users home directory - dot directory containing application
   $path = catdir( File::HomeDir->my_home, q(.).$appdir );
   $path = catdir( $path, qw(default lib), $classdir );
   $path = assert_directory $path and return $path;

   # 2c. Users home directory - dot file containing shell env variable
   $file = catfile( File::HomeDir->my_home, q(.).$prefix );
   $path = __read_variable( $file, q(APPLDIR) );
   $path and $path = catdir( $path, q(lib), $classdir );
   $path = assert_directory $path and return $path;

   # 3. Well known path containing shell env file
   $file = catfile( @{ DEFAULT_DIR() }, $appdir );
   $path = __read_variable( $file, q(APPLDIR) );
   $path and $path = catdir( $path, q(lib), $classdir );
   $path = assert_directory $path and return $path;

   # 4. Default install prefix
   $path = catdir( @{ PREFIX() }, $appdir );
   $path = catdir( $path, qw(default lib), $classdir );
   $path = assert_directory $path and return $path;

   # 5. Config file found in @INC
   for $path (map { catdir( abs_path( $_ ), $classdir ) } @INC) {
      for my $extn (keys %{ Class::Usul::File->extensions }) {
         $file = untaint_path catfile( $path, $prefix.$extn );
         -f $file and return dirname( $file );
      }
   }

   # 6. Default to /tmp
   return untaint_path( File::Spec->tmpdir );
}

sub __list_methods_of {
   return map  { s{ \A .+ :: }{}msx; $_ }
          grep { my $method = $_; grep { $_ eq q(method) }
                                  attributes::get( \&{ $method } ) }
              @{ Class::Inspector->methods
                    ( blessed $_[ 0 ] || $_[ 0 ], 'full', 'public' ) };
}

sub __map_prompt_args {
   my $args = shift; my %map = ( qw(-1 onechar -d default -e echo -p prompt) );

   for (grep { exists $map{ $_ } } keys %{ $args }) {
       $args->{ $map{ $_ } } = delete $args->{ $_ };
   }

   return $args;
}

sub __print_fh {
   my ($handle, $text) = @_;

   print {$handle} $text or throw error => 'IO error: [_1]', args =>[ $ERRNO ];
   return;
}

sub __prompt {
   my $args    = __map_prompt_args( arg_list @_ );
   my $default = $args->{default};
   my $echo    = $args->{echo   };
   my $onechar = $args->{onechar};
   my $OUT     = \*STDOUT;
   my $IN      = \*STDIN;
   my $input   = NUL;

   my ($len, $newlines, $next, $text);

   unless (is_interactive()) {
      $ENV{PERL_MM_USE_DEFAULT} and return $default;
      $onechar and return getc $IN;
      return scalar <$IN>;
   }

   my ($cntl, %cntl) = __get_control_chars( $IN );
   local $SIG{INT}   = sub { __restore_mode( $IN ); exit FAILED };

   __print_fh( $OUT, $args->{prompt} ); __raw_mode( $IN );

   while (TRUE) {
      if (defined ($next = getc $IN)) {
         if ($next eq $cntl{INTERRUPT}) {
            __restore_mode( $IN ); exit FAILED;
         }
         elsif ($next eq $cntl{ERASE}) {
            if ($len = length $input) {
               $input = substr $input, 0, $len - 1; __print_fh( $OUT, "\b \b" );
            }

            next;
         }
         elsif ($next eq $cntl{EOF}) {
            __restore_mode( $IN );
            close $IN or throw error => 'IO error: [_1]', args =>[ $ERRNO ];
            return $input;
         }
         elsif ($next !~ m{ $cntl }mx) {
            $input .= $next;

            if ($next eq "\n") {
               if ($input eq "\n" and defined $default) {
                  $text = defined $echo ? $echo x length $default : $default;
                  __print_fh( $OUT, "[${text}]\n" ); __restore_mode( $IN );

                  return $onechar ? substr $default, 0, 1 : $default;
               }

               $newlines .= "\n";
            }
            else { __print_fh( $OUT, $echo // $next ) }
         }
         else { $input .= $next }
      }

      if ($onechar or not defined $next or $input =~ m{ \Q$RS\E \z }mx) {
         chomp $input; __restore_mode( $IN );
         defined $newlines and __print_fh( $OUT, $newlines );
         return $onechar ? substr $input, 0, 1 : $input;
      }
   }

   return;
}

sub __raw_mode {
   my $handle = shift; ReadMode q(raw), $handle; return;
}

sub __read_variable {
   my ($file, $variable) = @_;

   return -f $file ? first { length }
                     map   { (split q(=), $_)[ 1 ] }
                     grep  { m{ \A $variable [=] }mx }
                     Class::Usul::File->io( $file )->chomp->getlines
                   : undef;
}

sub __restore_mode {
   my $handle = shift; ReadMode q(restore), $handle; return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

Class::Usul::Programs - Provide support for command line programs

=head1 Version

This document describes Class::Usul::Programs version 0.8.$Revision$

=head1 Synopsis

   # In YourClass.pm
   use Class::Usul::Moose;

   extends qw(Class::Usul::Programs);

   # In yourProg.pl
   use YourClass;

   exit YourClass->new( appclass => 'YourApplicationClass' )->run;

=head1 Description

This base class provides methods common to command line programs. The
constructor can initialise a multi-lingual message catalog if required

=head1 Configuration and Environment

Supports this list of command line options

=over 3

=item c method

The method in the subclass to dispatch to

=item D

Turn debugging on

=item H

Print long help text extracted from this POD

=item h

Print short help text extracted from this POD

=item L language

Print error messages in the selected language. If no language is
supplied print the error code and attributes

=item n

Do not prompt to turn debugging on

=item o key=value

The method that is dispatched to can access the key/value pairs
from the C<< $self->vars >> hash ref

=item q

Quietens the usual started/finished information messages

=back

=head1 Subroutines/Methods

=head2 BUILDARGS

Called just before the object is constructed this method modifier determines
the location of the config file

=head2 BUILD

Called just after the object is constructed this methods handles dispatching
to the help methods and prompting for the debug state

=head2 add_leader

   $leader = $self->add_leader( $text, $args );

Prepend C<< $self->config->name >> to each line of C<$text>. If
C<< $args->{no_lead} >> exists then do nothing. Return C<$text> with
leader prepended

=head2 anykey

   $key = $self->anykey( $prompt );

Prompt string defaults to 'Press any key to continue...'. Calls and
returns L<prompt|/prompt>. Requires the user to press any key on the
keyboard (that generates a character response)

=head2 can_call

   $bool = $self->can_call( $method );

Returns true if C<$self> has a method given by C<$method> that has defined
the I<method> method attribute

=head2 debug_flag

   $cmd_line_option = $self->debug_flag

Returns the command line debug flag to match the current debug state

=head2 dump_self

   $self->dump_self;

Dumps out the self referential object using L<Data::Dumper>

=head2 error

   $self->error( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Logs the result at the error level, then adds the
program leader and prints the result to I<STDERR>

=head2 fatal

   $self->fatal( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Logs the result at the alert level, then adds the
program leader and prints the result to I<STDERR>. Exits with a return
code of one

=head2 _get_debug_option

   $self->_get_debug_option();

If it is an interactive session prompts the user to turn debugging
on. Returns true if debug is on. Also offers the option to quit

=head2 _get_homedir

   $path = $self->_get_homedir( $args );

Environment variable containing the path to a file which contains
the application installation directory. Defaults to the environment
variable <uppercase application name>_HOME

Search through sub directories of @INC looking for the file
F<yourApplication.json>. Uses the location of this file to return the
path to the installation directory

=head2 get_line

   $line = $self->get_line( $question, $default, $quit, $width, $newline );

Prompts the user to enter a single line response to C<$question> which
is printed to I<STDOUT> with a program leader. If C<$quit> is true
then the options to quit is included in the prompt. If the C<$width>
argument is defined then the string is formatted to the specified
width which is C<$width> or C<< $self->pwdith >> or 40. If C<$newline>
is true a newline character is appended to the prompt so that the user
get a full line of input

=head2 get_meta

   $res_obj = $self->get_meta( $dir );

Extracts; I<name>, I<version>, I<author> and I<abstract> from the
F<META.yml> file.  Optionally look in C<$dir> for the file instead of
C<< $self->appldir >>. Returns a response object with accessors
defined

=head2 get_option

   $option = $self->get_option( $question, $default, $quit, $width, $options );

Returns the selected option number from the list of possible options passed
in the C<$question> argument

=head2 info

   $self->info( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Logs the result at the info level, then adds the
program leader and prints the result to I<STDOUT>

=head2 interpolate_cmd

   $cmd = $self->interpolate_cmd( $cmd, @args );

Calls C<_interpolate_${cmd}_cmd> to apply the arguments to the command in a
command specific way

=head2 list_methods

   $self->list_methods

Lists the methods (marked by the I<method> subroutine attribute) that can
be called via the L<run method|/run>

=head2 loc

   $localized_text = $self->loc( $key, @options );

Localizes the message. Calls L<Class::Usul::L10N/localize>. Adds the
constant C<DEFAULT_L10N_DOMAINS> to the list of domain files that are
searched. Adds C<< $self->language >> and C< $self->config->name >>
(search domain) to the arguments passed to C<localize>

=head2 output

   $self->output( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Adds the program leader and prints the result to
I<STDOUT>

=head2 _output_version

   $self->_output_version

Prints out the version of the C::U::Programs subclass and the exits

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

=head2 run

   $rv = $self->run;

Call the method specified by the C<-c> option on the command
line. Returns the exit code

=head2 _output_usage

   $self->_output_usage( $verbosity );

Print out usage information from POD. The C<$verbosity> is; 0, 1 or 2

=head2 warning

   $self->warning( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Logs the result at the warning level, then adds the
program leader and prints the result to I<STDOUT>

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

Turning debug on produces some more output

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<File::DataClass>

=item L<Getopt::Mixed>

=item L<IO::Interactive>

=item L<Term::ReadKey>

=item L<Text::Autoformat>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2012 Peter Flanigan. All rights reserved

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
