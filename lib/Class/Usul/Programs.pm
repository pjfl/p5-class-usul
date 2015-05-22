package Class::Usul::Programs;

use namespace::autoclean;

use Class::Usul::Constants qw( FAILED FALSE NUL OK SPC TRUE UNDEFINED_RV );
use Class::Usul::Functions qw( dash2under elapsed emit_to env_prefix exception
                               find_apphome get_cfgfiles is_arrayref is_hashref
                               logname throw untaint_cmdline
                               untaint_identifier );
use Class::Usul::Types     qw( Bool EncodingType HashRef Int SimpleStr );
use Config;
use English                qw( -no_match_vars );
use File::DataClass::Types qw( Directory OctalNum );
use Scalar::Util           qw( blessed );
use Try::Tiny;
use Moo;
use Class::Usul::Options;

extends q(Class::Usul);
with    q(Class::Usul::TraitFor::OutputLogging);
with    q(Class::Usul::TraitFor::Prompting);
with    q(Class::Usul::TraitFor::Usage);

# Private functions
my $_output_stacktrace = sub {
   my ($e, $verbose) = @_; ($e and blessed $e) or return; $verbose //= 0;

   $verbose > 0 and $e->can( 'trace' )
      and return emit_to \*STDERR, NUL.$e->trace;

   $e->can( 'stacktrace' ) and emit_to \*STDERR, NUL.$e->stacktrace;

   return;
};

# Attribute constructors
my $_build_debug = sub {
   my $self = shift; my $k = (env_prefix $self->config->appclass).'_DEBUG';

   return !!$ENV{ $k } ? TRUE : FALSE;
};

my $_build_os = sub {
   my $self = shift;
   my $file = 'os_'.$Config{osname}.$self->config->extension;
   my $path = $self->config->ctrldir->catfile( $file );

   $path->exists or return {};

   my $conf = $self->file->data_load( paths => [ $path ] );

   return $conf->{os} || {};
};

my $_build_run_method = sub {
   my $self = shift; my $method = untaint_identifier dash2under $self->method;

   unless ($self->can_call( $method )) {
      $method = untaint_identifier dash2under $self->extra_argv( 0 );
      $method = $self->can_call( $method )
              ? untaint_identifier dash2under $self->next_argv : NUL;
   }

   $method ||= 'run_chain';
  ($method eq 'help' or $method eq 'run_chain') and $self->quiet( TRUE );

   return $self->_set_method( $method );
};

# Override attribute default in base class
has '+config_class' => default => 'Class::Usul::Config::Programs';

# Public attributes
option 'debug'      => is => 'rwp',  isa => Bool, builder => $_build_debug,
   documentation    => 'Turn debugging on. Prompts if interactive',
   short            => 'D', lazy => TRUE;

option 'encoding'   => is => 'lazy', isa => EncodingType, format => 's',
   documentation    => 'Decode/encode input/output using this encoding',
   default          => sub { $_[ 0 ]->config->encoding };

option 'home'       => is => 'lazy', isa => Directory, coerce => TRUE,
   documentation    => 'Directory containing the configuration file',
   default          => sub { $_[ 0 ]->config->home },  format => 's';

option 'locale'     => is => 'ro',   isa => SimpleStr, format => 's',
   documentation    => 'Loads the specified language message catalogue',
   default          => sub { $_[ 0 ]->config->locale }, short => 'L';

option 'method'     => is => 'rwp',  isa => SimpleStr, default => NUL,
   documentation    => 'Name of the method to call',
   format           => 's', order => 1, short => 'c';

option 'noask'      => is => 'ro',   isa => Bool, default => FALSE,
   documentation    => 'Do not prompt for debugging',
   short            => 'n';

option 'options'    => is => 'ro',   isa => HashRef, format => 's%',
   documentation    =>
      'Zero, one or more key=value pairs available to the method call',
   default          => sub { {} }, short => 'o';

option 'quiet'      => is => 'ro',   isa => Bool, default => FALSE,
   documentation    => 'Quiet the display of information messages',
   reader           => 'quiet_flag', short => 'q';

option 'verbose'    => is => 'ro',   isa => Int,  default => 0,
   documentation    => 'Increase the verbosity of the output',
   repeatable       => TRUE, short => 'v';

has 'mode'          => is => 'rw',   isa => OctalNum, coerce => TRUE,
   default          => sub { $_[ 0 ]->config->mode },   lazy => TRUE;

has 'params'        => is => 'ro',   isa => HashRef, default => sub { {} };

# Private attributes
has '_os'           => is => 'lazy', isa => HashRef,
   builder          => $_build_os, init_arg => undef, reader => 'os';

has '_quiet_flag'   => is => 'rw',   isa => Bool,
   builder          => sub { $_[ 0 ]->quiet_flag },
   init_arg         => 'quiet', lazy => TRUE, writer => '_set__quiet_flag';

has '_run_method'   => is => 'lazy', isa => SimpleStr,
   builder          => $_build_run_method, init_arg => undef,
   reader           => 'run_method';

# Private methods
my $_apply_stdio_encoding = sub {
   my $self = shift; my $enc = untaint_cmdline $self->encoding;

   for (*STDIN, *STDOUT, *STDERR) {
      $_->opened or next; binmode $_, ":encoding(${enc})";
   }

   autoflush STDOUT TRUE; autoflush STDERR TRUE;
   return;
};

my $_catch_run_exception = sub {
   my ($self, $method, $error) = @_; my $e;

   unless ($e = exception $error) {
      $self->error( 'Method [_1] exception without error',
                    { args => [ $method ] } );
      return UNDEFINED_RV;
   }

   $e->out and $self->output( $e->out );
   $self->error( $e->error, { args => $e->args } );
   $self->debug and $_output_stacktrace->( $error, $self->verbose );

   return $e->rv || (defined $e->rv ? FAILED : UNDEFINED_RV);
};

my $_dont_ask = sub {
   return $_[ 0 ]->debug || ! $_[ 0 ]->is_interactive();
};

my $_get_debug_option = sub {
   my $self = shift;

   ($self->noask or $self->$_dont_ask) and return $self->debug;

   return $self->yorn( 'Do you want debugging turned on', FALSE, TRUE );
};

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
   my $self = shift; $self->$_apply_stdio_encoding;

   $self->help_usage   and $self->exit_usage( 0 );
   $self->help_options and $self->exit_usage( 1 );
   $self->help_manual  and $self->exit_usage( 2 );
   $self->show_version and $self->exit_version;

   $self->_set_debug( $self->$_get_debug_option );
   return;
}

# Public methods
sub debug_flag {
   return $_[ 0 ]->debug ? '-D' : '-n';
}

sub loc {
   my ($self, $key, @args) = @_; my $car = $args[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @args ] };

   $args->{locale           } //= $self->locale;
   $args->{quote_bind_values} //= TRUE;

   return $self->localize( $key, $args );
}

sub quiet {
   my ($self, $v) = @_; defined $v or return $self->_quiet_flag; $v = !!$v;

   $v != TRUE and throw 'Cannot turn quiet mode off';

   return $self->_set__quiet_flag( $v );
}

sub run {
   my $self = shift; my $method = $self->run_method; my $rv;

   my $text = 'Started by [_1] Version [_2] Pid [_3]';
   my $args = { args => [ logname, $self->app_version, abs $PID ] };

   $self->quiet or $self->output( $text, $args ); umask $self->mode;

   if ($method eq 'run_chain' or $self->can_call( $method )) {
      my $params = exists $self->params->{ $method }
                 ? $self->params->{ $method } : [];

      try {
         defined ($rv = $self->$method( @{ $params } ))
            or throw 'Method [_1] return value undefined',
                     args  => [ $method ], rv => UNDEFINED_RV;
      }
      catch { $rv = $self->$_catch_run_exception( $method, $_ ) };
   }
   else {
      $self->error( 'Class [_1] method [_2] not found',
                    { args => [ blessed $self, $method ] } );
      $rv = UNDEFINED_RV;
   }

   if (defined $rv and $rv == OK) {
      $self->quiet or $self->output
         ( 'Finished in [_1] seconds', { args => [ elapsed ] } );
   }
   elsif (defined $rv and $rv > OK) {
      $self->output( 'Terminated code [_1]', { args => [ $rv ], to => 'err' } )}
   else {
      not defined $rv and $rv = UNDEFINED_RV
         and $self->error( 'Method [_1] error uncaught or rv undefined',
                           { args => [ $method ] } );
      $self->output( 'Terminated with undefined rv', { to => 'err' } );
   }

   $self->file->delete_tmp_files;
   return $rv;
}

sub run_chain {
   my $self = shift;

   $self->error( 'Method unknown' ); $self->exit_usage( 0 );

   return; # Not reached
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

   exit YourClass->new_with_options( appclass => 'YourApplicationClass' )->run;

=head1 Description

This base class provides methods common to command line programs. The
constructor can initialise a multi-lingual message catalogue if required

=head1 Configuration and Environment

Supports this list of command line options:

=over 3

=item C<c method>

The method in the subclass to dispatch to

=item C<D debug>

Turn debugging on

=item C<encoding>

Decode/encode input/output using this encoding

=item C<home>

Directory containing the configuration file

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

=item C<v verbose>

Repeatable boolean that increases the verbosity of the output

=back

Defines these attributes;

=over 3

=item C<config_class>

Overrides the default in the base class, setting it to
C<Class::Usul::Config::Programs>

=item C<mode>

An octal number. Sets the umask during the method run

=item C<params>

List of value that are passed to the method called by L</run>

=back

=head1 Subroutines/Methods

=head2 BUILDARGS

Called just before the object is constructed this method modifier determines
the location of the config file

=head2 BUILD

Called just after the object is constructed this methods handles dispatching
to the help methods and prompting for the debug state

=head2 debug_flag

   $cmd_line_option = $self->debug_flag

Returns the command line debug flag to match the current debug state

=head2 _get_debug_option

   $self->_get_debug_option();

If it is an interactive session prompts the user to turn debugging
on. Returns true if debug is on. Also offers the option to quit

=head2 loc

   $localized_text = $self->loc( $message, @options );

Localises the message. Calls L<Class::Usul::L10N/localize>. The
domains to search are in the C<l10n_domains> configuration attribute. Adds
C<< $self->locale >> to the arguments passed to C<localize>

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

=head1 Diagnostics

Turning debug on produces log output at the debug level

=head1 Dependencies

=over 3

=item L<Class::Usul::IPC>

=item L<Class::Usul::File>

=item L<Class::Usul::Options>

=item L<Encode>

=item L<Moo>

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
