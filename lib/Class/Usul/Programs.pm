package Class::Usul::Programs;

use attributes ();
use namespace::autoclean;

use Moo;
use Class::Inspector;
use Class::Usul::Constants qw( BRK FAILED FALSE NUL OK SPC
                               TRUE UNDEFINED_RV WIDTH );
use Class::Usul::File;
use Class::Usul::Functions qw( abs_path elapsed emit emit_err emit_to
                               exception find_apphome find_source
                               get_cfgfiles is_arrayref is_hashref is_member
                               logname pad throw untaint_identifier );
use Class::Usul::IPC;
use Class::Usul::Options;
use Class::Usul::Types     qw( ArrayRef Bool EncodingType FileType HashRef
                               Int IPCType LoadableClass PositiveInt
                               PromptType SimpleStr );
use Config;
use English                qw( -no_match_vars );
use File::Basename         qw( dirname );
use File::DataClass::Types qw( Directory );
use List::Util             qw( first );
use Pod::Eventual::Simple;
use Pod::Man;
use Pod::Usage;
use Scalar::Util           qw( blessed );
use Text::Autoformat;
use Try::Tiny;

extends q(Class::Usul);
with    q(Class::Usul::TraitFor::Prompting);

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
   documentation      => 'Loads the specified language message catalogue',
   default            => sub { $_[ 0 ]->config->locale }, short => 'L';

option 'method'       => is => 'rwp',  isa => SimpleStr, format => 's',
   documentation      => 'Name of the method to call',
   default            => NUL, order => 1, short => 'c';

option 'noask'        => is => 'ro',   isa => Bool, default => FALSE,
   documentation      => 'Do not prompt for debugging',
   short              => 'n';

option 'options'      => is => 'ro',   isa => HashRef, format => 's%',
   documentation      =>
      'Zero, one or more key=value pairs available to the method call',
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

has 'meta_class'  => is => 'lazy', isa => LoadableClass,
   default        => 'Class::Usul::Response::Meta',
   coerce         => LoadableClass->coercion;

has 'mode'        => is => 'rw',   isa => PositiveInt,
   default        => sub { $_[ 0 ]->config->mode }, lazy => TRUE;

has 'params'      => is => 'ro',   isa => HashRef, default => sub { {} };

# Private attributes
has '_file'       => is => 'lazy', isa => FileType,
   builder        => sub { Class::Usul::File->new( builder => $_[ 0 ] ) },
   init_arg       => undef, reader => 'file';

has '_ipc'        => is => 'lazy', isa => IPCType,
   builder        => sub { Class::Usul::IPC->new( builder => $_[ 0 ] ) },
   handles        => [ qw( run_cmd ) ], init_arg => undef, reader => 'ipc';

has '_os'         => is => 'lazy', isa => HashRef, init_arg => undef,
   reader         => 'os';

has '_quiet_flag' => is => 'rw',   isa => Bool,
   default        => sub { $_[ 0 ]->quiet_flag },
   init_arg       => 'quiet', lazy => TRUE, writer => '_set__quiet_flag';

has '_run_method' => is => 'lazy', isa => SimpleStr, init_arg => undef,
   reader         => 'run_method';

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   my $cfg = $attr->{config} //= {}; $attr->{noask} //= delete $attr->{nodebug};

   $cfg->{appclass} //= delete $attr->{appclass} || blessed $self || $self;
   $cfg->{home    } //= find_apphome $cfg->{appclass}, $attr->{home};
   $cfg->{cfgfiles} //= get_cfgfiles $cfg->{appclass},  $cfg->{home};

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

sub _build__os {
   my $self = shift;
   my $file = 'os_'.$Config{osname}.$self->config->extension;
   my $path = $self->config->ctrldir->catfile( $file );

   $path->exists or return {};

   my $cfg  = $self->file->data_load( paths => [ $path ] );

   return $cfg->{os} || {};
}

sub _build__run_method {
   my $self = shift; my $method = __dash2underscore( $self->method );

   unless ($self->can_call( $method )) {
      $method = __dash2underscore( $self->extra_argv( 0 ) );
      $method = $self->can_call( $method )
              ? __dash2underscore( $self->next_argv ) : NUL;
   }

   $method ||= 'run_chain';
  ($method eq 'help' or $method eq 'run_chain') and $self->quiet( TRUE );

   return $self->_set_method( $method );
}

# Public methods
sub add_leader {
   my ($self, $text, $args) = @_; $text or return NUL; $args ||= {};

   my $leader = $args->{no_lead} ? NUL : (ucfirst $self->config->name).BRK;

   if ($args->{fill}) {
      my $width = $args->{width} || WIDTH;

      $text = autoformat $text, { right => $width - 1 - length $leader };
   }

   return join "\n", map { (m{ \A $leader }mx ? NUL : $leader).$_ }
                     split  m{ \n }mx, $text;
}

sub can_call {
   return ($_[ 1 ] && $_[ 0 ]->can( $_[ 1 ] )
           && (is_member $_[ 1 ], __list_methods_of( $_[ 0 ] ))) ? TRUE : FALSE;
}

sub debug_flag {
   return $_[ 0 ]->debug ? '-D' : '-n';
}

sub dump_self : method {
   my $self = shift;

   $self->dumper( $self ); $self->dumper( $self->config );
   return OK;
}

sub error {
   my ($self, $err, $args) = @_;

   my $text = $self->loc( $err || '[no message]', $args->{args} || [] );

   $self->log->error( $_ ) for (split m{ \n }mx, "${text}");

   emit_to *STDERR, $self->add_leader( $text, $args )."\n";
   $self->debug and __output_stacktrace( $err, $self->verbose );
   return;
}

sub fatal {
   my ($self, $err, $args) = @_; my (undef, $file, $line) = caller 0;

   my $posn = ' at '.abs_path( $file )." line ${line}";

   my $text = $self->loc( $err || '[no message]', $args->{args} || [] );

   $self->log->alert( $_ ) for (split m{ \n }mx, $text.$posn);

   emit_to *STDERR, $self->add_leader( $text, $args ).$posn."\n";
   __output_stacktrace( $err, $self->verbose );
   exit FAILED;
}

sub help : method {
   my $self = shift; $self->_output_usage( 0 ); return OK;
}

sub info {
   my ($self, $text, $args) = @_;

   my $opts = { params => $args->{args} || [], quote_bind_values => FALSE, };

   $text = $self->loc( $text || '[no message]', $opts );

   $self->log->info( $_ ) for (split m{ [\n] }mx, $text);

   $self->quiet or emit $self->add_leader( $text, $args );
   return;
}

sub interpolate_cmd {
   my ($self, $cmd, @args) = @_;

   my $ref = $self->can( "_interpolate_${cmd}_cmd" ) or return [ $cmd, @args ];

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

      emit( (pad $key, $max).SPC.(join SPC, @rest) );
   }

   return OK;
}

sub loc {
   my ($self, $key, @args) = @_; my $car = $args[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @args ] };

   $args->{locale           } //= $self->locale;
   $args->{quote_bind_values} //= TRUE;

   return $self->localize( $key, $args );
}

sub output {
   my ($self, $text, $args) = @_; $args ||= {};

   $text = $self->loc( $text || '[no message]', $args->{args} || [] );

   my $code = sub {
      $args->{to} && $args->{to} eq 'err' ? emit_err( @_ ) : emit( @_ );
   };

   $code->() if $args->{cl};
   $code->( $self->add_leader( $text, $args ) );
   $code->() if $args->{nl};
   return;
}

sub quiet {
   my ($self, $v) = @_; defined $v or return $self->_quiet_flag; $v = !!$v;

   $v != TRUE and throw 'Cannot turn quiet mode off';

   return $self->_set__quiet_flag( $v );
}

sub run {
   my $self  = shift; my $method = $self->run_method; my $rv;

   my $text  = 'Started by '.logname.' Version '.($self->VERSION || '?').SPC;
      $text .= 'Pid '.(abs $PID);

   $self->quiet or $self->output( $text ); umask $self->mode;

   if ($method eq 'run_chain' or $self->can_call( $method )) {
      my $params = exists $self->params->{ $method }
                 ? $self->params->{ $method } : [];

      try {
         defined ($rv = $self->$method( @{ $params } ))
            or throw 'Method [_1] return value undefined',
                     args  => [ $method ], rv => UNDEFINED_RV;
      }
      catch { $rv = $self->_catch_run_exception( $method, $_ ) };
   }
   else {
      $self->error( 'Class '.(blessed $self)." method ${method} not found" );
      $rv = UNDEFINED_RV;
   }

   if (defined $rv and $rv == OK) {
      $self->quiet or $self->output( 'Finished in '.elapsed.' seconds' );
   }
   elsif (defined $rv and $rv > OK) {
      $self->output( "Terminated code ${rv}", { to => 'err' } ) }
   else {
      not defined $rv and $rv = UNDEFINED_RV
         and $self->error( "Method ${method} error uncaught/rv undefined" );
      $self->output( 'Terminated with undefined rv', { to => 'err' } );
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

# Private methods
sub _apply_stdio_encoding {
   my $self = shift; my $enc = $self->encoding;

   for (*STDIN, *STDOUT, *STDERR) {
      $_->opened or next; binmode $_, ":encoding(${enc})";
   }

   autoflush STDOUT TRUE; autoflush STDERR TRUE;
   return;
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
       || $_[ 0 ]->help_manual || ! $_[ 0 ]->is_interactive();
}

sub _exit_usage {
   $_[ 0 ]->quiet( TRUE ); exit $_[ 0 ]->_output_usage( $_[ 1 ] );
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

   ($self->noask or $self->_dont_ask) and return $self->debug;

   return $self->yorn( 'Do you want debugging turned on', FALSE, TRUE );
}

sub _man_page_from {
   my ($self, $src) = @_; my $cfg = $self->config;

   my $parser   = Pod::Man->new( center  => $cfg->doc_title || NUL,
                                 name    => $cfg->script,
                                 release => 'Version '.$self->VERSION,
                                 section => '3m' );
   my $tempfile = $self->file->tempfile;
   my $cmd      = $cfg->man_page_cmd || [];

   $parser->parse_from_file( NUL.$src->pathname, $tempfile->pathname );
   emit $self->run_cmd( [ @{ $cmd }, $tempfile->pathname ] )->out;
   return OK;
}

sub _output_usage {
   my ($self, $verbose) = @_; my $method = $self->next_argv;

   defined $method and $method = untaint_identifier $method;

   $self->can_call( $method ) and return $self->_usage_for( $method );

   $verbose > 1 and return $self->_man_page_from( $self->config );

   $verbose > 0 and pod2usage( { -exitval => OK,
                                 -input   => NUL.$self->config->pathname,
                                 -message => SPC,
                                 -verbose => $verbose } ); # Never returns

   emit_to \*STDERR, $self->options_usage;
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
sub __dash2underscore {
   (my $x = $_[ 0 ]) =~ s{ [\-] }{_}gmx; return $x;
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
          grep { my $subr = $_;
                 grep { $_ eq 'method' } attributes::get( \&{ $subr } ) }
              @{ Class::Inspector->methods
                    ( blessed $_[ 0 ] || $_[ 0 ], 'full', 'public' ) };
}

sub __output_stacktrace {
   my ($e, $verbose) = @_; ($e and blessed $e) or return; $verbose //= 0;

   $verbose > 0 and $e->can( 'trace' )
      and return emit_to \*STDERR, NUL.$e->trace;

   $e->can( 'stacktrace' ) and emit_to \*STDERR, NUL.$e->stacktrace;

   return;
}

1;

__END__

=pod

=head1 Name

Class::Usul::Programs - Provide support for command line programs

=head1 Synopsis

   # In YourClass.pm
   use Moo;

   extends q(Class::Usul::Programs);

   # In yourProg.pl
   use YourClass;

   exit YourClass->new( appclass => 'YourApplicationClass' )->run;

=head1 Description

This base class provides methods common to command line programs. The
constructor can initialise a multi-lingual message catalogue if required

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
catalogue is supplied prints text and errors in terse English. Defaults
to C<en_GB>

=item C<n noask>

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

   $localized_text = $self->loc( $message, @options );

Localises the message. Calls L<Class::Usul::L10N/localize>. The
domains to search are in the C<l10n_domains> configuration attribute. Adds
C<< $self->locale >> to the arguments passed to C<localize>

=head2 output

   $self->output( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Adds the program leader and prints the result to
I<STDOUT>

=head2 quiet

   $bool = $self->quiet( $bool );

Custom accessor/mutator for the C<quiet_flag> attribute. Will throw if you try
to turn quiet mode off

=head2 run

   $exit_code = $self->run;

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

=head1 Diagnostics

Turning debug on produces some more output

=head1 Dependencies

=over 3

=item L<Class::Inspector>

=item L<Class::Usul::IPC>

=item L<Class::Usul::File>

=item L<Class::Usul::Options>

=item L<Encode>

=item L<Moo>

=item L<Text::Autoformat>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

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
