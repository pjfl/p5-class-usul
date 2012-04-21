# @(#)$Id$

package Class::Usul::Programs;

use strict;
use attributes ();
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use Class::Inspector;
use Class::Usul::IPC;
use Class::Usul::File;
use Class::Usul::Constants;
use Class::Usul::Response::Meta;
use Class::Usul::Functions qw(app_prefix arg_list assert_directory class2appdir
                              classdir elapsed env_prefix exception
                              is_member prefix2class say split_on__ throw
                              untaint_identifier untaint_path);
use Cwd                    qw(abs_path);
use Encode                 qw(decode);
use English                qw(-no_match_vars);
use File::Basename         qw(basename);
use File::Spec::Functions  qw(catdir catfile);
use IO::Interactive        qw(is_interactive);
use List::Util             qw(first);
use Scalar::Util           qw(blessed);
use Config;
use Pod::Man;
use Pod::Usage;
use File::HomeDir;
use Term::ReadKey;
use Text::Autoformat;
use Try::Tiny;

extends qw(Class::Usul);
with    qw(MooseX::Getopt::Dashes Class::Usul::Encoding);

__PACKAGE__->make_log_methods();

has 'debug',       => is => 'rw', isa => 'Bool', default => FALSE,
   documentation   => 'Turn debugging on. Promps if interactive',
   traits          => [ 'Getopt' ], cmd_aliases => q(D), cmd_flag => 'debug',
   trigger         => \&_debug_set;

has 'help_options' => is => 'ro', isa => 'Bool', default => FALSE,
   documentation   => 'Uses Pod::Usage to describe the program usage options',
   traits          => [ 'Getopt' ], cmd_aliases => q(h), cmd_flag => 'options';

has 'help_manual'  => is => 'ro', isa => 'Bool', default => FALSE,
   documentation   => 'Uses Pod::Man to display the program documentation',
   traits          => [ 'Getopt' ], cmd_aliases => q(H), cmd_flag => 'man_page';

has 'homedir'      => is => 'ro', isa => 'Str',
   documentation   => 'Directory containing the configuration file',
   traits          => [ 'Getopt' ], cmd_flag => 'home';

has 'language'     => is => 'ro', isa => 'Str',  default => NUL,
   documentation   => 'Loads the specified language message catalog',
   traits          => [ 'Getopt' ], cmd_aliases => q(L), cmd_flag => 'language';

has 'method'       => is => 'ro', isa => 'Str',  default => NUL,
   documentation   => 'Name of the method to call. Required',
   traits          => [ 'Getopt' ], cmd_aliases => q(c), cmd_flag => 'command';

has 'nodebug'      => is => 'ro', isa => 'Bool', default => FALSE,
   documentation   => 'Do not prompt for debugging',
   traits          => [ 'Getopt' ], cmd_aliases => q(n), cmd_flag => 'nodebug';

has 'params'       => is => 'ro', isa => 'HashRef', default => sub { {} },
   documentation   =>
      'Zero, one or more key/value pairs passed to the method call',
   traits          => [ 'Getopt' ], cmd_aliases => q(o), cmd_flag => 'option';

has 'quiet'        => is => 'ro', isa => 'Bool', default => FALSE,
   documentation   => 'Quiet the display of information messages',
   traits          => [ 'Getopt' ], cmd_aliases => q(q), cmd_flag => 'quiet';

has 'version'      => is => 'ro', isa => 'Bool', default => FALSE,
   documentation   => 'Displays the version number of the program class',
   traits          => [ 'Getopt' ], cmd_aliases => q(V), cmd_flag => 'version';


has '_file'    => is => 'ro', isa     => 'Object',  init_arg => undef,
   reader      => 'file',     lazy    => TRUE,      builder  => '_build__file',
   handles     => [ qw(io) ];

has '_ipc'     => is => 'ro', isa     => 'Object',  init_arg => undef,
   reader      => 'ipc',      lazy    => TRUE,      builder  => '_build__ipc',
   handles     => [ qw(run_cmd) ];

has '_logname' => is => 'ro', isa     => 'Str',     init_arg => undef,
   reader      => 'logname',  default => $ENV{USER} || $ENV{LOGNAME};

has '_os'      => is => 'ro', isa     => 'HashRef', init_arg => undef,
   reader      => 'os',       lazy    => TRUE,      builder  => '_build__os';

around BUILDARGS => sub {
   my ($next, $class, @args) = @_; my $attr = $class->$next( @args );

   $attr->{appclass} ||= prefix2class basename( $PROGRAM_NAME, EXTNS );
   $attr->{home    } ||= __get_homedir( $attr );
   $attr->{config  } ||= __load_config( $attr );

   return $attr;
};

sub BUILD {
   my $self = shift; $self->_apply_encoding;

   $self->help_manual  and $self->_output_usage( 2 );
   $self->help_options and $self->_output_usage( 1 );
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
   my ($self, $prompt) = @_; $prompt ||= 'Press any key to continue...';

   return __prompt( -p => $prompt, -e => NUL, -1 => TRUE );
}

sub can_call {
   my ($self, $method) = @_;

   return (is_member $method, __list_methods_of( $self )) ? TRUE : FALSE;
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

   $self->log_error( $_ ) for (split m{ \n }mx, NUL.$err);

   __print_fh( \*STDERR, $self->add_leader( $err, $args )."\n" );
   return;
}

sub fatal {
   my ($self, $err, $args) = @_; my (undef, $file, $line) = caller 0;

   $err ||= 'unknown'; my $posn = ' at '.abs_path( $file )." line ${line}";

   $self->log_alert( $_ ) for (split m{ \n }mx, $err.$posn);

   __print_fh( \*STDERR, $self->add_leader( $err, $args ).$posn."\n" );

   $err and blessed $err
        and $err->can( q(stacktrace) )
        and __print_fh( \*STDERR, $err->stacktrace."\n" );

   exit FAILED;
}

sub get_line {
   # General text input routine.
   my ($self, $question, $default, $quit, $width, $multiline, $noecho) = @_;

   $question ||= 'Enter your answer';
   $default    = defined $default ? q([).$default.q(]) : NUL;

   my $advice       = $quit ? '('.QUIT.' to quit)' : NUL;
   my $right_prompt = $advice.($multiline ? NUL : SPC.$default);
   my $left_prompt  = $question;

   if (defined $width) {
      my $total  = $width || $self->pwidth || 60;
      my $left_x = $total - (length $right_prompt);

      $left_prompt = sprintf '%-*s', $left_x, $question;
   }

   my $prompt  = $left_prompt.SPC.$right_prompt;
      $prompt .= ($multiline ? "\n".$default : NUL).BRK;
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

   $opt !~ m{ \A \d+ \z }mx and $opt = defined $default ? $default : 0;

   return $opt - 1;
}

sub get_owner {
   my ($self, $pi_cfg) = @_; $pi_cfg ||= {};

   return ($self->params->{uid} || getpwnam( $pi_cfg->{owner} ) || 0,
           $self->params->{gid} || getgrnam( $pi_cfg->{group} ) || 0);
}

sub info {
   my ($self, $err, $args) = @_;

   $self->log_info( $_ ) for (split m{ [\n] }mx, $err);

   $self->quiet or say $self->add_leader( $err, $args );
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
   my ($self, @rest) = @_;

   my $params = { lang => $self->language, ns => $self->config->name };

   return $self->next::method( $params, @rest );
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
      umask $self->config->mode;

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

   $self->log_warn( $_ ) for (split m{ \n }mx, $err);

   $self->quiet or say $self->add_leader( $err, $args );
   return;
}

sub yorn {
   # General yes or no input routine
   my ($self, $question, $default, $quit, $width, $newline) = @_;

   my $no = NO; my $yes = YES; my $result;

   $default = $default ? $yes : $no; $quit = $quit ? QUIT : NUL;

   my $advice       = $quit ? "(${yes}/${no}, ${quit}) " : "(${yes}/${no}) ";
   my $right_prompt = $advice.q([).$default.q(]);
   my $left_prompt  = $question;

   if (defined $width) {
      my $max_width = $width || $self->config->pwidth || 40;
      my $right_x   = length $right_prompt;
      my $left_x    = $max_width - $right_x;

      $left_prompt = sprintf '%-*s', $left_x, $question;
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

sub _build__file {
   my $self = shift;

   return Class::Usul::File->new( { config => $self->config } );
}

sub _build__ipc {
   my $self = shift;

   return Class::Usul::IPC->new( { config => $self->config,
                                   debug  => $self->debug,
                                   file   => $self->file,
                                   log    => $self->log } );
}

sub _build__os {
   my $self = shift;
   my $file = q(os_).$Config{osname}.$self->config->extension;
   my $path = $self->config->ctrldir->catfile( $file );

   $path->exists or return {};

   my $cfg  = $self->file->data_load( arrays => [ q(os) ],
                                      path   => $path ) || {};

   return $cfg->{os} || {};
}

sub _debug_set {
   my ($self, $debug) = @_;

   $self->SUPER::debug( $debug ); $self->ipc->debug( $debug );

   return;
}

sub _dont_ask {
   return $_[ 0 ]->debug || $_[ 0 ]->help_flag || $_[ 0 ]->help_options
       || $_[ 0 ]->help_manual || ! is_interactive();
}

sub _getopt_full_usage {
   # Required to stop MX::Getopt from printing usage
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
   my ($self, $verbose) = @_; my $method = $self->extra_argv->[ 0 ];

   $method and $self->can_call( $method ) and exit $self->_usage_for( $method );

   $verbose > 1 and exit $self->_man_page_from( $self->config );

   pod2usage( { -input   => NUL.$self->config->pathname, -message => SPC,
                -verbose => $verbose } );
   exit OK; # Never reached
}

sub _output_version {
   my $self = shift; $self->output( 'Version '.$self->VERSION ); exit OK;
}

sub _usage_for {
   my ($self, $method) = @_; my @classes = (blessed $self);

   $method = untaint_identifier $method;

   while (my $class = shift @classes) {
      no strict q(refs);

      if (defined &{ "${class}::${method}" }) {
         my $selector = Pod::Select->new(); $selector->select( q(/).$method );
         my $source   = $self->file->find_source( $class );
         my $tempfile = $self->file->tempfile;

         $selector->parse_from_file( $source, $tempfile->pathname );
         return $self->_man_page_from( $tempfile );
      }

      push @classes, $_ for (@{ "${class}::ISA" });
   }

   return FAILED;
}

# Private functions

sub __get_control_chars {
   my $handle = shift; my %cntl = GetControlChars $handle;

   return ((join q(|), values %cntl), %cntl);
}

sub __get_homedir {
  my $attr = shift; my $appclass = $attr->{appclass}; my $path;

   # 0. Pass the directory in
   $path = assert_directory $attr->{homedir} and return $path;

   # 1. Environment variable
   $path = $ENV{ (env_prefix $appclass).q(_HOME) };
   $path = assert_directory $path and return $path;

   # 2a. Users home directory - application directory
   my $appdir = class2appdir $appclass; my $classdir = classdir $appclass;

   $path = catdir( File::HomeDir->my_home, $appdir );
   $path = catdir( $path, qw(default lib), $classdir );
   $path = assert_directory $path and return $path;

   # 2b. Users home directory - dotfile
   $path = catdir( File::HomeDir->my_home, q(.).$appdir );
   $path = assert_directory $path and return $path;

   # 3. Well known path
   my $well_known = catfile( @{ DEFAULT_DIR() }, $appdir );

   $path = __read_path_from( $well_known );
   $path and $path = catdir( $path, q(lib), $classdir );
   $path = assert_directory $path and return $path;

   # 4. Default install prefix
   $path = catdir( @{ PREFIX() }, $appdir );
   $path = catdir( $path, qw(default lib), $classdir );
   $path = assert_directory $path and return $path;

   # 5. Config file found in @INC
   my $file = app_prefix $appclass;

   for my $dir (map { catdir( abs_path( $_ ), $classdir ) } @INC) {
      $path = untaint_path catfile( $dir, $file.CONFIG_EXTN );

      -f $path and return dirname( $path );
   }

   # 6. Default to /tmp
   return untaint_path File::Spec->tmpdir;
}

sub __list_methods_of {
   my $arg = shift; my $class = blessed $arg || $arg;

   return map  { s{ \A .+ :: }{}msx; $_ }
          grep { my $x = $_;
                 grep { $_ eq q(method) } attributes::get( \&{ $x } ) }
              @{ Class::Inspector->methods( $class, 'full', 'public' ) };
}

sub __load_config {
   my $attr   = shift;
   my $file   = (app_prefix $attr->{appclass} ).CONFIG_EXTN;
   my $path   = catfile( $attr->{home}, $file );
   # Now we know where the config file should be we can try parsing it
   my $config = -f $path ? Class::Usul::File->data_load( path => $path ) : {};

   return { %{ $attr }, %{ $config || {} } };
}

sub __map_prompt_args {
   my $args = shift; my %map = ( qw(-1 onechar -d default -e echo -p prompt) );

   for (keys %{ $args }) {
      exists $map{ $_ } and $args->{ $map{ $_ } } = delete $args->{ $_ };
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
            else { __print_fh( $OUT, defined $echo ? $echo : $next ) }
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

sub __read_path_from {
   my $path = shift;

   return -f $path ? first { length }
                     map   { (split q(=), $_)[ 1 ] }
                     grep  { m{ \A APPLDIR= }mx }
                     Class::Usul::File->io( $path )->chomp->getlines
                   : undef;
}

sub __restore_mode {
   my $handle = shift; ReadMode q(restore), $handle; return;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

Class::Usul::Programs - Provide support for command line programs

=head1 Version

This document describes Class::Usul::Programs version 0.1.$Revision$

=head1 Synopsis

   # In YourClass.pm
   use Moose;

   extends qw(Class::Usul::Programs);

   # In yourProg.pl
   use YourClass;

   exit YourClass->new( appclass => 'YourApplicationClass' )->run;

=head1 Description

This base class provides methods common to command line programs. The
constructor can initialise a multi-lingual message catalog if required

=head1 Subroutines/Methods

=head2 BUILDARGS

=head2 BUILD

=head3 applclass

The name of the application to which the program using this class
belongs. It is used to find the application installation directory
which will contain the configuration XML file

=head3 arglist

Additional L<Getopts::Mixed> command line initialisation arguments are
appended to the default list shown below:

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

=item S

Suppresses the usual started/finished information messages

=back

=head3 debug

Boolean which if true causes program debug output to be
generated. Defaults to false

=head3 install

The path to a file which contains the application installation
directory.

=head3 n

Boolean which if true will stop the constructor from prompting the
user to turn debugging on. Defaults to false

=head3 prefix

Defaults to /opt/<application name>

=head3 script

The name of the program. Defaults to the value returned by L<caller>

=head3 quiet

Boolean which if true suppresses the usual started/finished
information messages. Defaults to false

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

Search through subdirectories of @INC looking for the file
myApplication.xml. Uses the location of this file to return the path to
the installation directory

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

=head2 info

   $self->info( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Logs the result at the info level, then adds the
program leader and prints the result to I<STDOUT>

=head2 loc

   $local_text = $self->localize( $key, $args );

Localizes the message. Calls L<Class::Usul::L10N/localize>


=head2 output

   $self->output( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Adds the program leader and prints the result to
I<STDOUT>

=head2 output_version

Prints out the version of the C::U::Programs subclass

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

=head1 Configuration and Environment

None

=head1 Diagnostics

Turning debug on produces some more output

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Class::Usul::InflateSymbols>

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

Copyright (c) 2010 Peter Flanigan. All rights reserved

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
