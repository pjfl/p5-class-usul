# @(#)$Ident: Programs.pm 2013-09-02 15:52 pjf ;

package Class::Usul::Programs;

use attributes ();
use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.26.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Inspector;
use Class::Usul::Constants;
use Class::Usul::Functions  qw( abs_path arg_list elapsed emit
                                exception find_apphome find_source
                                get_cfgfiles is_arrayref is_hashref is_member
                                logname pad throw untaint_identifier );
use Class::Usul::File;
use Class::Usul::IPC;
use Class::Usul::Types      qw( ArrayRef Bool EncodingType FileType HashRef Int
                                IPCType LoadableClass NonZeroPositiveInt
                                PositiveInt SimpleStr );
use Config;
use English                 qw( -no_match_vars );
use File::Basename          qw( dirname );
use File::DataClass::Types  qw( Directory );
use IO::Interactive         qw( is_interactive );
use List::Util              qw( first );
use Moo;
use MooX::Options;
use Pod::Eventual::Simple;
use Pod::Man;
use Pod::Usage;
use Scalar::Util            qw( blessed );
use Term::ReadKey;
use Text::Autoformat;
use Try::Tiny;

extends q(Class::Usul);
with    q(Class::Usul::TraitFor::LoadingClasses);

my $EXTNS = [ keys %{ Class::Usul::File->extensions } ];

# Override attributes in base class
has '+config_class'   => default => sub { 'Class::Usul::Config::Programs' };

# Public attributes
option 'debug'        => is => 'rw',   isa => Bool, default => FALSE,
   documentation      => 'Turn debugging on. Prompts if interactive',
   short              => 'D', trigger => TRUE;

option 'encoding'     => is => 'lazy', isa => EncodingType, format => 's',
   documentation      => 'Decode/encode input/output using this encoding',
   default            => sub { $_[ 0 ]->config->encoding };

option 'help_manual'  => is => 'ro',   isa => Bool, default => FALSE,
   documentation      => 'Displays the documentation for the program',
   short              => 'H';

option 'help_options' => is => 'ro',   isa => Bool, default => FALSE,
   documentation      => 'Describes program options and methods',
   short              => 'h';

option 'help_usage'   => is => 'ro',   isa => Bool, default => FALSE,
   documentation      => 'Displays this command line usage',
   short              => '?';

option 'home'         => is => 'lazy', isa => Directory, format => 's',
   documentation      => 'Directory containing the configuration file',
   default            => sub { $_[ 0 ]->config->home },
   coerce             => Directory->coercion;

option 'locale'       => is => 'ro',   isa => SimpleStr, format => 's',
   documentation      => 'Loads the specified language message catalog',
   default            => sub { $_[ 0 ]->config->locale }, short => 'L';

option 'method'       => is => 'rw',   isa => SimpleStr, format => 's',
   documentation      => 'Name of the method to call',
   default            => NUL, order => 1, short => 'c';

option 'nodebug'      => is => 'ro',   isa => Bool, default => FALSE,
   documentation      => 'Do not prompt for debugging',
   short              => 'n';

option 'options'      => is => 'ro',   isa => HashRef, format => 's%',
   documentation      =>
      'Zero, one or more key/value pairs available to the method call',
   default            => sub { {} }, short => 'o';

option 'quiet'        => is => 'ro',   isa => Bool, default => FALSE,
   documentation      => 'Quiet the display of information messages',
   reader             => 'quiet_flag', short => 'q';

option 'verbose'      => is => 'ro',   isa => Int,  default => 0,
   documentation      => 'Increase the verbosity of the output',
   repeatable         => TRUE, short => 'v';

option 'version'      => is => 'ro',   isa => Bool, default => FALSE,
   documentation      => 'Displays the version number of the program class',
   short              => 'V';

with q(Class::Usul::TraitFor::UntaintedGetopts);

has 'meta_class'  => is => 'lazy', isa => LoadableClass,
   default        => 'Class::Usul::Response::Meta',
   coerce         => LoadableClass->coercion;

has 'mode'        => is => 'rw',   isa => PositiveInt,
   default        => sub { $_[ 0 ]->config->mode }, lazy => TRUE;

has 'params'      => is => 'ro',   isa => HashRef, default => sub { {} };

has 'pwidth'      => is => 'rw',   isa => NonZeroPositiveInt, default => 60;

# Private attributes
has '_file'       => is => 'lazy', isa => FileType,
   default        => sub { Class::Usul::File->new( builder => $_[ 0 ] ) },
   handles        => [ qw( io ) ], init_arg => undef, reader => 'file';

has '_ipc'        => is => 'lazy', isa => IPCType,
   default        => sub { Class::Usul::IPC->new( builder => $_[ 0 ] ) },
   handles        => [ qw( run_cmd ) ], init_arg => undef, reader => 'ipc';

has '_os'         => is => 'lazy', isa => HashRef, init_arg => undef,
   reader         => 'os';

has '_quiet_flag' => is => 'rw',   isa => Bool,
   default        => sub { $_[ 0 ]->quiet_flag },
   init_arg       => 'quiet', lazy => TRUE, writer => '_set__quiet_flag';

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   my $cfg = $attr->{config} ||= {};

   $cfg->{appclass} ||= delete $attr->{appclass} || blessed $self || $self;
   $cfg->{home    } ||= find_apphome $cfg->{appclass}, $attr->{home}, $EXTNS;
   $cfg->{cfgfiles} ||= get_cfgfiles $cfg->{appclass},  $cfg->{home}, $EXTNS;

   return $attr;
};

sub BUILD {
   my $self = shift; $self->_apply_stdio_encoding;

   $self->help_usage   and $self->_exit_usage( 0 );
   $self->help_options and $self->_exit_usage( 1 );
   $self->help_manual  and $self->_exit_usage( 2 );
   $self->version      and $self->_exit_version;

   $self->debug( $self->_get_debug_option );
   return;
}

# Public methods
sub add_leader {
   my ($self, $text, $args) = @_; $text or return NUL; $args ||= {};

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
   my $prompt = $_[ 1 ] || $_[ 0 ]->loc( 'Press any key to continue...' );

   return __prompt( -p => $prompt, -e => NUL, -1 => TRUE );
}

sub can_call {
   return ($_[ 0 ]->can( $_[ 1 ] )
           && (is_member $_[ 1 ], __list_methods_of( $_[ 0 ] ))) ? TRUE : FALSE;
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

   my $text = $self->loc( $err || '[no message]', $args->{args} || [] );

   $self->log->error( $_ ) for (split m{ \n }mx, NUL.$text);

   __print_fh( \*STDERR, $self->add_leader( $text, $args )."\n" );
   $self->debug and __output_stacktrace( $err, $self->verbose );
   return;
}

sub fatal {
   my ($self, $err, $args) = @_; my (undef, $file, $line) = caller 0;

   my $posn = ' at '.abs_path( $file )." line ${line}";

   my $text = $self->loc( $err || '[no message]', $args->{args} || [] );

   $self->log->alert( $_ ) for (split m{ \n }mx, $text.$posn);

   __print_fh( \*STDERR, $self->add_leader( $text, $args ).$posn."\n" );
   __output_stacktrace( $err, $self->verbose );
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
   my ($self, $dir) = @_; my $cfg = $self->config;

   my @dirs = ($cfg->appldir, $cfg->ctrldir);

   $dir and unshift @dirs, $self->io( $dir );

   return $self->meta_class->new( directories => \@dirs );
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

sub help : method {
   my $self = shift; $self->_output_usage( 0 ); return OK;
}

sub info {
   my ($self, $text, $args) = @_;

   $text = $self->loc( $text || '[no message]', $args->{args} || [] );

   $self->log->info( $_ ) for (split m{ [\n] }mx, $text);

   $self->quiet or emit $self->add_leader( $text, $args );
   return;
}

sub interpolate_cmd {
   my ($self, $cmd, @args) = @_;

   my $ref = $self->can( q(_interpolate_).$cmd.q(_cmd) )
      or return [ $cmd, @args ];

   return $self->$ref( $cmd, @args );
}

sub list_methods : method {
   my $self = shift; my $abstract = {}; my $max = 0;

   my $classes = $self->_get_classes_and_roles;

   for my $method (__list_methods_of( $self )) {
      my $mlen = length $method; $mlen > $max and $max = $mlen;

      for my $class (@{ $classes }) {
         is_member( $method, Class::Inspector->methods( $class, 'public' ))
            or next;

         my $pod = __get_pod_header_for_method( $class, $method ) or next;

         (not exists $abstract->{ $method }
           or length $pod > length $abstract->{ $method })
            and $abstract->{ $method } = $pod;
      }
   }

   for my $key (sort keys %{ $abstract }) {
      my ($method, @rest) = split SPC, $abstract->{ $key };

      emit( (pad $method, $max).SPC.(join SPC, @rest) );
   }

   return OK;
}

sub loc {
   my ($self, $key, @args) = @_; my $car = $args[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @args ] };

   $args->{domain_names} ||= [ DEFAULT_L10N_DOMAIN, $self->config->name ];
   $args->{locale      } ||= $self->locale;

   return $self->localize( $key, $args );
}

sub output {
   my ($self, $text, $args) = @_; $args ||= {};

   $self->quiet and return; $args->{cl} and emit;

   $text = $self->loc( $text || '[no message]', $args->{args} || [] );

   emit $self->add_leader( $text, $args ); $args->{nl} and emit;

   return;
}

sub quiet {
   my ($self, $v) = @_; defined $v or return $self->_quiet_flag; $v = !!$v;

   $v != TRUE and throw 'Cannot turn quiet mode off';

   return $self->_set__quiet_flag( $v );
}

sub run {
   my $self  = shift; my $method = $self->_get_run_method; my $rv;

   my $text  = 'Started by '.logname.' Version '.($self->VERSION || '?').SPC;
      $text .= 'Pid '.(abs $PID);

   $self->output( $text ); umask $self->mode;

   if ($method eq 'run_chain' or $self->can_call( $method )) {
      my $params = exists $self->params->{ $method }
                 ? $self->params->{ $method } : [];

      try {
         defined ($rv = $self->$method( @{ $params } ))
            or throw error => 'Method [_1] return value undefined',
                     args  => [ $method ], rv => UNDEFINED_RV;
      }
      catch { $rv = $self->_catch_run_exception( $method, $_ ) };
   }
   else {
      $self->error( 'Class '.(blessed $self)." method ${method} not found" );
      $rv = UNDEFINED_RV;
   }

   if (defined $rv and $rv == OK) {
      $self->output( 'Finished in '.elapsed.' seconds' );
   }
   elsif (defined $rv and $rv > OK) { $self->output( "Terminated code ${rv}" ) }
   else {
      not defined $rv and $rv = UNDEFINED_RV
         and $self->error( "Method ${method} error uncaught/rv undefined" );
      $self->output( 'Terminated with undefined rv' );
   }

   $self->file->delete_tmp_files;
   return $rv;
}

sub run_chain {
   my ($self, $method) = @_; $method or $self->_exit_usage( 0 );

   $self->fatal( exception "Method ${method} unknown" );
   return FAILED;
}

sub warning {
   my ($self, $text, $args) = @_;

   $text = $self->loc( $text || '[no message]', $args->{args} || [] );

   $self->log->warn( $_ ) for (split m{ \n }mx, $text);

   $self->quiet or emit $self->add_leader( $text, $args );
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
sub _apply_stdio_encoding {
   my $self = shift; my $enc = $self->encoding;

   binmode $_, ":encoding(${enc})" for (*STDIN, *STDOUT, *STDERR);

   autoflush STDOUT TRUE; autoflush STDERR TRUE;
   return;
}

sub _build__os {
   my $self = shift;
   my $file = q(os_).$Config{osname}.$self->config->extension;
   my $path = $self->config->ctrldir->catfile( $file );

   $path->exists or return {};

   my $cfg  = $self->file->data_load( paths => [ $path ] );

   return $cfg->{os} || {};
}

sub _catch_run_exception {
   my ($self, $method, $error) = @_; my $e;

   unless ($e = exception $error) {
      $self->error( 'Method [_1] exception without error',
                    { args => [ $method ] } );
      return UNDEFINED_RV;
   }

   $e->out and $self->output( $e->out );
   $self->error( $e->error, { args => $e->args } );

   return $e->rv || (defined $e->rv ? FAILED : UNDEFINED_RV);
}

sub _dont_ask {
   return $_[ 0 ]->debug || $_[ 0 ]->help_usage || $_[ 0 ]->help_options
       || $_[ 0 ]->help_manual || ! is_interactive();
}

sub _exit_usage {
   exit $_[ 0 ]->_output_usage( $_[ 1 ] );
}

sub _exit_version {
   $_[ 0 ]->output( 'Version '.$_[ 0 ]->VERSION ); exit OK;
}

sub _get_classes_and_roles {
   my $self = shift; my %uniq = (); require mro;

   my @classes = @{ mro::get_linear_isa( blessed $self ) };

   while (my $class = shift @classes) {
      $uniq{ $class } and next; $uniq{ $class }++;

      exists $Role::Tiny::APPLIED_TO{ $class }
         and push @classes, keys %{ $Role::Tiny::APPLIED_TO{ $class } };
   }

   return [ sort keys %uniq ];
}

sub _get_debug_option {
   my $self = shift;

   ($self->nodebug or $self->_dont_ask) and return $self->debug;

   return $self->yorn( 'Do you want debugging turned on', FALSE, TRUE );
}

sub _get_run_method {
   my $self = shift; my $method = $self->method;

   unless ($method) {
      if ($method = $self->extra_argv( 0 ) and $self->can_call( $method )) {
         $method = $self->next_argv;
      }
      else { $method = NUL }
   }

   $method ||= 'run_chain'; $method eq 'run_chain' and $self->quiet( TRUE );

   return $self->method( $method );
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
   emit $self->run_cmd( [ @{ $cmd }, $tempfile->pathname ] )->out;
   return OK;
}

sub _output_usage {
   my ($self, $verbose) = @_; my $method = $self->next_argv;

   defined $method and $method = untaint_identifier $method;

   $method and $self->can_call( $method )
      and return $self->_usage_for( $method );

   $verbose > 1 and return $self->_man_page_from( $self->config );

   if ($verbose > 0) {
      pod2usage( { -input   => NUL.$self->config->pathname, -message => SPC,
                   -verbose => $verbose } ); # Never returns
   }

   my $usage = ucfirst $self->options_usage;

   warn $usage ? $usage : "Did we forget new_with_options?\n";
   return FAILED;
}

sub _usage_for {
   my ($self, $method) = @_;

   for my $class (@{ $self->_get_classes_and_roles }) {
      is_member( $method, Class::Inspector->methods( $class, 'public' ) )
         or next;

      my $selector = Pod::Select->new(); my $tfile = $self->file->tempfile;

      $selector->select( "/${method}.*" );
      $selector->parse_from_file( find_source $class, $tfile->pathname );
      $tfile->stat->{size} > 0 and return $self->_man_page_from( $tfile );
   }

   return FAILED;
}

# Private functions
sub __get_control_chars {
   my $handle = shift; my %cntl = GetControlChars $handle;

   return ((join q(|), values %cntl), %cntl);
}

sub __get_pod_header_for_method {
   my ($class, $method) = @_;

   my $pod = Pod::Eventual::Simple->read_file( find_source $class );
   my $out = [ grep { $_->{content} =~ m{ (?: ^|[< ]) $method (?: [ >]|$ ) }msx}
               grep { $_->{type} eq 'command' } @{ $pod } ]->[ 0 ]->{content};

   $out and chomp $out;
   return $out;
}

sub __list_methods_of {
   return map  { s{ \A .+ :: }{}msx; $_ }
          grep { my $method = $_; grep { $_ eq 'method' }
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

sub __output_stacktrace {
   my ($e, $verbose) = @_; ($e and blessed $e) or return; $verbose //= 0;

   $verbose > 0 and $e->can( 'trace' )
      and return __print_fh( \*STDERR, NUL.$e->trace );

   $e->can( 'stacktrace' ) and __print_fh( \*STDERR, NUL.$e->stacktrace );

   return;
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

sub __restore_mode {
   my $handle = shift; ReadMode q(restore), $handle; return;
}

1;

__END__

=pod

=head1 Name

Class::Usul::Programs - Provide support for command line programs

=head1 Version

This document describes version v0.26.$Rev: 1 $ of L<Class::Usul::Programs>

=head1 Synopsis

   # In YourClass.pm
   use Moo;

   extends q(Class::Usul::Programs);

   # In yourProg.pl
   use YourClass;

   exit YourClass->new( appclass => 'YourApplicationClass' )->run;

=head1 Description

This base class provides methods common to command line programs. The
constructor can initialise a multi-lingual message catalog if required

=head1 Configuration and Environment

Supports this list of command line options:

=over 3

=item C<c method>

The method in the subclass to dispatch to

=item C<D>

Turn debugging on

=item C<H help_manual>

Print long help text extracted from this POD

=item C<h help_options>

Print short help text extracted from this POD

=item C<? help_usage>

=item C<L locale>

Print text and error messages in the selected language. If no language
catalog is supplied prints text and errors in terse English. Defaults
to C<en_GB>

=item C<n nodebug>

Do not prompt to turn debugging on

=item C<o options key=value>

The method that is dispatched to can access the key/value pairs
from the C<< $self->options >> hash ref

=item C<q quiet_flag>

Quietens the usual started/finished information messages

=item C<version>

Prints the programs version number and exits

=back

Defines these attributes;

=over 3

=item C<config_class>

Overrides the default in the base class, setting it to
C<Class::Usul::Config::Programs>

=item C<params>

List of value that are passed to the method called by L</run>

=item C<v verbose>

Repeatable boolean that increases the verbosity of the output

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

=head2 dump_self - Dumps the program object

   $self->dump_self;

Dumps out the self referential object using L<Data::Printer>

=head2 error

   $self->error( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Logs the result at the error level, then adds the
program leader and prints the result to I<STDERR>

=head2 _exit_usage

   $self->_exit_usage( $verbosity );

Print out usage information from POD. The C<$verbosity> is; 0, 1 or 2

=head2 _exit_version

   $self->_exit_version

Prints out the version of the C::U::Programs subclass and the exits

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
F<META.json> or F<META.yml> file.  Looks in the optional C<$dir> directory
for the file in addition to C<< $self->appldir >> and C<< $self->ctrldir >>.
Returns a response object with read-only accessors defined

=head2 get_option

   $option = $self->get_option( $question, $default, $quit, $width, $options );

Returns the selected option number from the list of possible options passed
in the C<$question> argument

=head2 help - Display help text about a method

   $exit_code = $self->help;

Searches the programs classes and roles to find the method implementation.
Displays help text from the POD that describes the method

=head2 info

   $self->info( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Logs the result at the info level, then adds the
program leader and prints the result to I<STDOUT>

=head2 interpolate_cmd

   $cmd = $self->interpolate_cmd( $cmd, @args );

Calls C<_interpolate_${cmd}_cmd> to apply the arguments to the command in a
command specific way

=head2 list_methods - Lists available command line methods

   $self->list_methods;

Lists the methods (marked by the I<method> subroutine attribute) that can
be called via the L<run method|/run>

=head2 loc

   $localized_text = $self->loc( $key, @options );

Localizes the message. Calls L<Class::Usul::L10N/localize>. Adds the
constant C<DEFAULT_L10N_DOMAINS> to the list of domain files that are
searched. Adds C<< $self->locale >> and C< $self->config->name >>
(search domain) to the arguments passed to C<localize>

=head2 output

   $self->output( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Adds the program leader and prints the result to
I<STDOUT>

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

=head2 quiet

   $bool = $self->quiet( $bool );

Custom accessor/mutator for the C<quiet_flag> attribute. Will throw if you try
to turn quiet mode off

=head2 run

   $rv = $self->run;

Call the method specified by the C<-c> option on the command
line. Returns the exit code

=head2 run_chain

   $exit_code = $self->run_chain( $method );

Called by L</run> when C<_get_run_method> cannot determine which method to
call. Outputs usage if C<$method> is undefined. Logs an error if
C<$method> is defined but not (by definition a callable method).
Returns exit code C<FAILED>

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

=item L<Class::Inspector>

=item L<Class::Usul>

=item L<Class::Usul::IPC>

=item L<Class::Usul::File>

=item L<Class::Usul::TraitFor::LoadingClasses>

=item L<Class::Usul::TraitFor::UntaintedGetopts>

=item L<Encode>

=item L<IO::Interactive>

=item L<Moo>

=item L<MooX::Options>

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
