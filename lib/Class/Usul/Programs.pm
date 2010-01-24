# @(#)$Id$

package Class::Usul::Programs;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::I18N;
use Class::Usul::Response::Meta;
use Moose;
use Config;
use Pod::Man;
use TryCatch;
use File::Spec;
use Pod::Usage;
use XML::Simple;
use Term::ReadKey;
use Text::Autoformat;
use Cwd             qw(abs_path);
use English         qw(-no_match_vars);
use Getopt::Mixed   qw(nextOption);
use IO::Interactive qw(is_interactive);
use List::Util      qw(first);
use Sys::Hostname     ();

extends qw(Class::Usul);

has 'appclass' => is => 'ro', isa => 'Str',            required => TRUE;
has 'arglist'  => is => 'ro', isa => 'Str',            default  => NUL;
has 'args'     => is => 'rw', isa => 'HashRef',        default  => sub { {} };
has 'home'     => is => 'ro', isa => 'F_DC_Directory', coerce   => TRUE;
has 'language' => is => 'rw', isa => 'Str',            default  => NUL;
has 'logname'  => is => 'ro', isa => 'Str',
   default     => $ENV{USER} || $ENV{LOGNAME};
has 'messages' => is => 'rw', isa => 'HashRef',        default  => sub { {} };
has 'method'   => is => 'rw', isa => 'Str',            default  => NUL;
has 'name'     => is => 'ro', isa => 'Str',            required => TRUE;
has 'os'       => is => 'ro', isa => 'HashRef',        default  => sub { {} };
has 'parms'    => is => 'ro', isa => 'HashRef',        default  => sub { {} };
has 'prefix'   => is => 'ro', isa => 'Str',            required => TRUE;
has 'silent'   => is => 'rw', isa => 'Bool',           default  => FALSE;
has 'vars'     => is => 'rw', isa => 'HashRef',        default  => sub { {} };

with qw(Class::Usul::IPC);

around BUILDARGS => sub {
   my ($orig, $class, @args) = @_;

   my $attr = $class->arg_list( @args );

   $attr->{script  } ||= $class->basename( $attr->{script} || $PROGRAM_NAME );

   my $prog = $class->basename( lc $attr->{script}, $attr->{extns} || EXTNS );

   $attr->{prefix  } ||= $class->split_on__( $prog, 0 );
   $attr->{name    } ||= $class->split_on__( $prog, 1 ) || $prog;
   $attr->{appclass} ||= ucfirst $attr->{prefix};
   $attr->{home    } ||= $class->_get_homedir    ( $attr );
   $attr->{config  } ||= $class->_load_config    ( $attr );
                         $class->_inflate_config ( $attr );
   $attr->{os      } ||= $class->_load_os_depends( $attr );

   exists $attr->{n} and $attr->{args}->{n} = TRUE;

   return $class->$orig( $attr );
};

sub BUILD {
   my $self = shift;

   autoflush STDOUT 1; autoflush STDERR 1;

   Getopt::Mixed::init( q(c=s D H h L=s n o=s S ).$self->arglist );

   $self->_load_args_ref; $self->_load_vars_ref;

   Getopt::Mixed::cleanup();

   $self->_set_attr  ( q(c), q(method)         );
   $self->_set_attr  ( q(L), q(language)       );
   $self->_set_attr  ( q(S), q(silent)         );
   $self->debug      ( $self->get_debug_option );
   $self->lock->debug( $self->debug            );
   $self->messages   ( $self->_load_messages   );

   return;
}

sub add_leader {
   my ($self, $text, $args) = @_; $args ||= {};

   $text = $self->loc( $text || '[no message]', @{ $args->{args} || [] } );

   my $leader = exists $args->{noLead} || exists $args->{no_lead}
              ? NUL : (ucfirst $self->name).BRK;

   if ($args->{fill}) {
      my $width = $args->{width} || WIDTH;

      $text = autoformat $text, { right => $width - 1 - length $leader };
   }

   return join "\n", map { (m{ \A $leader }mx ? NUL : $leader).$_ }
                     split  m{ \n }mx, $text;
}

sub anykey {
   my ($self, $prompt) = @_; $prompt ||= 'Press any key to continue...';

   return $self->prompt( -p => $prompt, -e => NUL, -1 => TRUE );
}

sub dispatch {
   my $self = shift; my ($rv, $text);

   exists $self->args->{h} and $self->usage(1);
   exists $self->args->{H} and $self->usage(2);

   my $method = $self->method || $self->usage(0);

   $text  = 'Started by '.$self->logname.' Version '.$VERSION.SPC;
   $text .= 'Pid '.(abs $PID);
   $self->output( $text );

   if ($self->can( $method )) {
      umask oct ($self->config->{mode} || PERMS);

      my $parms = exists $self->parms->{ $method }
                ? $self->parms->{ $method } : [];

      try { $rv = $self->$method( @{ $parms } ) }
      catch ($error) {
         my $e = $self->catch( $error );

         $e->out and $self->output( $e->out );
         $self->error( $e->as_string( $self->debug ), { args => $e->args } );
         $rv = $e->rv || -1;
      }

      unless (defined $rv) {
         $self->error( "Method $method return value undefined" ); $rv = -1;
      }
   }
   else {
      $self->error( "Method $method not defined in class ".(ref $self) );
      $rv = -1;
   }

   if (defined $rv and not $rv) { $self->output( 'Finished' ) }
   else { $self->output( "Terminated code $rv" ) }

   $self->delete_tmp_files;
   return $rv;
}

sub error {
   my ($self, $text, $args) = @_;

   $text = $self->add_leader( $text, $args );

   $self->log_error( $_ ) for (split m{ \n }mx, $text);

   $self->_print_fh( \*STDERR, $text."\n" );
   return;
}

sub fatal {
   my ($self, $text, $args) = @_; my (undef, $file, $line) = caller 0;

   $text  = $self->add_leader( $text, $args );
   $text .= ' at '.abs_path( $file ).' line '.$line;

   $self->log_alert( $_ ) for (split m{ \n }mx, $text);

   $self->_print_fh( \*STDERR, $text."\n" );
   exit 1;
}

sub get_debug_option {
   my $self = shift; my $args = $self->args || {};

   exists $args->{D}   and return TRUE;
   __dont_ask( $args ) and return FALSE;
   is_interactive()    or  return FALSE;

   return $self->yorn( 'Do you want debugging turned on', FALSE, TRUE );
}

sub get_line {
   # General text input routine.
   my ($self, $question, $default, $quit, $width, $newline, $pword) = @_;

   $question ||= 'Enter your answer';
   $default    = defined $default ? $default : NUL;

   my $advice       = $quit ? '('.QUIT.' to quit) ' : NUL;
   my $right_prompt = $advice.(defined $default ? q([).$default.q(]) : NUL);
   my $left_prompt;

   if (defined $width) {
      my $total    = $width || $self->config->{pwidth} || 40;
      my $right_x  = length $right_prompt;
      my $left_x   = $total - $right_x;

      $left_prompt = sprintf '%-*s', $left_x, $question;
   }
   else { $left_prompt = $question }

   my $prompt = $left_prompt.SPC.$right_prompt.BRK.($newline ? "\n" : NUL);
   my $result = $pword
              ? $self->prompt( -d => $default, -p => $prompt, -e => q(*) )
              : $self->prompt( -d => $default, -p => $prompt );

   $quit and defined $result and lc $result eq QUIT and exit 1;

   return NUL.$result;
}

sub get_meta {
   my ($self, $path) = @_; my $meta_class = q(Class::Usul::Response::Meta);

   my @paths = ( $self->catfile( $self->config->{appldir}, q(META.yml) ),
                 $self->catfile( $self->config->{ctrldir}, q(META.yml) ),
                 q(META.yml) );

   $path and unshift @paths, $path;

   return $meta_class->new( $_ ) for (grep { -f $_ } @paths);

   $self->throw( 'No META.yml file' );
   return;
}

sub info {
   my ($self, $text, $args) = @_;

   $text = $self->add_leader( $text, $args );

   $self->log_info( $_ ) for (split m{ \n }mx, $text);

   $self->silent or $self->say( $text );
   return;
}

*loc = \&localize;

sub localize {
   my ($self, @rest) = @_;

   return Class::Usul::I18N->localize( $self->messages, @rest );
}

sub output {
   my ($self, $text, $args) = @_;

   $self->silent and return;
   $args and $args->{cl} and $self->say;
   $self->say( $self->add_leader( $text, $args ) );
   $args and $args->{nl} and $self->say;
   return;
}

sub prompt {
   my ($self, @rest) = @_; my ($len, $newlines, $next, $text);

   my $IN      = \*STDIN;
   my $OUT     = \*STDOUT;
   my $args    = $self->_map_prompt_args( $self->arg_list( @rest ) );
   my $default = $args->{default};
   my $echo    = $args->{echo   };
   my $onechar = $args->{onechar};
   my $input   = NUL;

   unless (is_interactive()) {
      return $default if ($ENV{PERL_MM_USE_DEFAULT});
      return getc $IN if ($onechar);
      return scalar <$IN>;
   }

   my ($cntl, %cntl) = $self->_get_control_chars( $IN );
   local $SIG{INT}   = sub { $self->_restore_mode( $IN ); exit 1 };

   $self->_print_fh( $OUT, $args->{prompt} );
   $self->_raw_mode( $IN );

   while (TRUE) {
      if (defined ($next = getc $IN)) {
         if ($next eq $cntl{INTERRUPT}) {
            $self->_restore_mode( $IN );
            exit 1;
         }
         elsif ($next eq $cntl{ERASE}) {
            if ($len = length $input) {
               $input = substr $input, 0, $len - 1;
               $self->_print_fh( $OUT, "\b \b" );
            }

            next;
         }
         elsif ($next eq $cntl{EOF}) {
            $self->_restore_mode( $IN );
            close $IN
               or $self->throw( error => 'IO error [_1]', args =>[ $ERRNO ] );
            return $input;
         }
         elsif ($next !~ m{ $cntl }mx) {
            $input .= $next;

            if ($next eq "\n") {
               if ($input eq "\n" and defined $default) {
                  $text = defined $echo ? $echo x length $default : $default;
                  $self->_print_fh( $OUT, "[${text}]\n" );
                  $self->_restore_mode( $IN );

                  return $onechar ? substr $default, 0, 1 : $default;
               }

               $newlines .= "\n";
            }
            else { $self->_print_fh( $OUT, defined $echo ? $echo : $next ) }
         }
         else { $input .= $next }
      }

      if ($onechar or not defined $next or $input =~ m{ \Q$RS\E \z }mx) {
         chomp $input; $self->_restore_mode( $IN );
         defined $newlines and $self->_print_fh( $OUT, $newlines );
         return $onechar ? substr $input, 0, 1 : $input;
      }
   }

   return;
}

sub usage {
   my ($self, $verbose) = @_;

   if ($verbose < 2) {
      pod2usage( { -input   => $self->config->{pathname},
                   -message => SPC, -verbose => $verbose } );
      exit 0; # Never reached
   }

   my $doc_title = $self->config->{doc_title} || NUL;
   my $parser    = Pod::Man->new( center  => $doc_title,
                                  name    => $self->appclass,
                                  release => 'Version '.$main::VERSION,
                                  section => q(3m) );
   my $tempfile = $self->tempfile;
   my $cmd      = q(cat ).$tempfile->pathname.q( | nroff -man);

   $parser->parse_from_file( $self->config->{pathname}, $tempfile->pathname );
   system $cmd;
   exit 0;
}

sub warning {
   my ($self, $text, $args) = @_;

   $text = $self->add_leader( $text, $args );

   $self->log_warning( $_ ) for (split m{ \n }mx, $text);

   $self->silent or $self->say( $text );
   return;
}

sub yorn {
   # General yes or no input routine
   my ($self, $question, $default, $quit, $width, $newline) = @_;

   my $no = NO; my $yes = YES; my $result;

   $default = $default ? $yes : $no; $quit = $quit ? QUIT : NUL;

   my $advice       = $quit ? "($yes/$no, $quit) " : "($yes/$no) ";
   my $right_prompt = $advice.q([).$default.q(]);
   my $left_prompt  = $question;

   if (defined $width) {
      my $total    = $width || $self->config->{pwidth} || 40;
      my $right_x  = length $right_prompt;
      my $left_x   = $total - $right_x;

      $left_prompt = sprintf '%-*s', $left_x, $question;
   }

   my $prompt = $left_prompt.SPC.$right_prompt.BRK;

   $newline and $prompt .= "\n";

   while ($result = $self->prompt( -d => $default, -p => $prompt )) {
      exit   1     unless (defined $result);
      exit   1     if     ($quit and $result =~ m{ \A (?: $quit | [\e] ) }imx);
      return TRUE  if     ($result =~ m{ \A $yes }imx);
      return FALSE if     ($result =~ m{ \A $no  }imx);
   }

   return;
}

# Private methods

sub _get_control_chars {
   my ($self, $handle) = @_; my %cntl = GetControlChars $handle;

   return ((join q(|), values %cntl), %cntl);
}

sub _get_homedir {
   my ($self, $args) = @_;

   my $class = $args->{appclass};
   my $path  = $ENV{ $args->{evar} || $self->env_prefix( $class ).q(_HOME) };

   $path and -d $path and return $path;

   my $app_prefix = $self->app_prefix( $class );

   $path = $self->catfile( NUL, qw(etc default), $app_prefix );

   my $well_known = $args->{install} || $path; $path = undef;

   -f $well_known and $path = first { length }
                              grep  { not m{ \A \# }mx }
                              $self->io( $well_known )->chomp->getlines;
   $path and -d $path and return $path;
   $path = $self->catdir( @{ PREFIX() }, $self->class2appdir( $class ) );

   my $prefix   = $args->{install_prefix} || $path;
   my $dir_path = $self->catdir( split m{ :: }mx, $class );

   $path = $self->catdir( $prefix, qw(default lib), $dir_path );

   -d $path and return $path;

   for (@INC) {
      $path = $self->catfile( $_, $dir_path, $app_prefix.q(.xml) );
      -f $path and return abs_path( $self->dirname( $path ) );
   }

   return File::Spec->tmpdir;
}

sub _inflate_config {
   my ($class, $args) = @_;

   my $defaults = {
      appldir => '__APPLDIR__', binsdir => '__BINSDIR__', phase => PHASE,
   };

   $class->_inflate_values( $args, $defaults );

   $defaults = {
      pathname => '__binsdir('.$args->{script}.')__',
      shell    => $class->catfile( NUL, qw(bin ksh) ),
      suid     => '__binsdir('.$args->{prefix}.'_admin)__',
      vardir   => '__appldir(var)__',
   };

   $class->_inflate_values( $args, $defaults );

   $defaults = {
      ctrldir  => '__vardir(etc)__',
      dbasedir => '__vardir(db)__',
      logsdir  => '__vardir(logs)__',
      root     => '__vardir(root)__',
      rundir   => '__vardir(run)__',
      tempdir  => '__vardir(tmp)__',
   };

   $class->_inflate_values( $args, $defaults );

   my $conf = $args->{config};

   -d $conf->{tempdir}
      or $conf->{tempdir} = $class->untaint_path( File::Spec->tmpdir );
   -d $conf->{logsdir}
      or $conf->{logsdir} = $conf->{tempdir};

   $defaults = {
      ctlfile  => '__ctrldir('.$args->{name}.q(.xml).')__',
      logfile  => '__logsdir('.$args->{name}.q(.log).')__',
   };

   $class->_inflate_values( $args, $defaults );

   $conf->{hostname }   = Sys::Hostname::hostname();
   $conf->{no_thrash} ||= 3;
   $conf->{owner    } ||= $args->{prefix} || q(root);
   $conf->{pwidth   } ||= 60;

   # TODO: Move this
   $defaults = {};
   $defaults->{ q(aliases_path)  } = $class->catfile( $conf->{ctrldir},
                                                      q(aliases) );
   $defaults->{ q(profiles_path) } = $class->catfile( $conf->{ctrldir},
                                                      q(user_profiles.xml) );
   $class->_inflate_values( $args, $defaults );
   return;
}

sub _inflate_values {
   my ($class, $args, $defaults) = @_; my $conf = $args->{config};

   my @keys = ( keys %{ $defaults } );

   for (@keys) {
      $conf->{ $_ } = $class->_inflate_value( $args, $defaults, $_ );
   }

   return;
}

sub _inflate_value {
   my ($class, $args, $defaults, $key) = @_; my $conf = $args->{config};

   my $v = $conf->{ $key } || $defaults->{ $key }; defined $v or return;

   if ($v =~ m{ __PHASE__ }mx) {
      ($v) = $conf->{appldir} =~ m{ \A v \d+ \. \d+ p (\d+) \z }msx;

      return defined $v ? $v : PHASE;
   }

   my $symbols = {
      '__APPLDIR__' => sub {
         my $v = $class->dirname( $Config{sitelibexp} );

         if ($args->{home} =~ m{ \A $v }mx) {
            $v = $class->class2appdir( $args->{name} );
            $v = $class->catdir( NUL, qw(var www), $v, q(default) );
         }
         else { $v = $class->home2appl( $args->{home} ) }

         return $v;
      },
      '__BINSDIR__' => sub {
         my $v = $class->dirname( $Config{sitelibexp} );

         if ($args->{home} =~ m{ \A $v }mx) { $v = $Config{scriptdir} }
         else { $v = $class->catdir( $conf->{appldir}, q(bin) ) }

         return $v;
      },
      '__appldir\( (.*) \)__' => sub {
         return $class->catdir( $conf->{appldir}, $_[0] );
      },
      '__binsdir\( (.*) \)__' => sub {
         return $class->catdir( $conf->{binsdir}, $_[0] );
      },
      '__ctrldir\( (.*) \)__' => sub {
         return $class->catdir( $conf->{ctrldir}, $_[0] );
      },
      '__logsdir\( (.*) \)__' => sub {
         return $class->catdir( $conf->{logsdir}, $_[0] );
      },
      '__path_to\( (.*) \)__' => sub {
         return $class->catdir( $args->{home}, $_[0] );
      },
      '__vardir\( (.*) \)__' => sub {
         return $class->catdir( $conf->{vardir}, $_[0] );
      },
   };

   for my $pattern (keys %{ $symbols }) {
      if ($v =~ m{ $pattern }mx) {
         $v = $symbols->{ $pattern }->( $1 ); last;
      }
   }

   return abs_path( $class->untaint_path( $v ) );
}

sub _load_args_ref {
   my $self = shift; my $args = $self->args; my ($k, $v);

   while (($k, $v) = nextOption()) {
      if ($args->{ $k }) {
         if (ref $args->{ $k } eq ARRAY) { push @{ $args->{ $k } }, $v }
         else { $args->{ $k } = [ $args->{ $k }, $v ] }
      }
      else { $args->{ $k } = $v }
   }

   return;
}

sub _load_config {
   my ($class, $args) = @_; my $cfg = {};

   # Now we know where the config file should be we can try parsing it
   my $file = $class->app_prefix( $args->{appclass} );
   my $path = $class->catfile   ( $args->{home}, $file.q(.xml) );

   if (-f $path) {
      try { $cfg = XML::Simple->new( SuppressEmpty => TRUE )->xml_in( $path ) }
      catch ($e) { $class->throw( $e ) }
   }

   return $cfg;
}

sub _load_messages {
   my $self = shift;
   my $lang = $self->language or return {};
   my $file = q(default_).$lang.q(.xml);
   my $path = $self->catfile( $self->config->{ctrldir}, $file );
   my $cfg;

   return {} unless ($path = $self->untaint_path( $path ) and -f $path);

   try {
      my $xs   = XML::Simple->new( ForceArray => [ q(messages) ] );
      my $text = $self->io( $path )->lock->all;

      $text = join "\n", grep { not m{ <! .+ > }mx } split m{ \n }mx, $text;
      $cfg  = $xs->xml_in( $text ) || {};
   }
   catch ($e) { $self->error( $e ) }

   return $cfg->{messages} || {};
}

sub _load_os_depends {
   my ($self, $args) = @_; my $dir = $args->{config}->{ctrldir}; my $cfg;

   my $path = $self->catfile( $dir, q(os_).$Config{osname}.q(.xml) );

   return {} unless ($path = $self->untaint_path( $path ) and -f $path);

   try {
      my $text = $self->io( $path )->lock->all;
      my $xs   = XML::Simple->new( ForceArray => [ q(os) ] );

      $text = join "\n", grep { not m{ <! .+ > }mx } split m{ \n }mx, $text;
      $cfg  = $xs->xml_in( $text ) || {};
   }
   catch ($e) { $self->error( $e ) }

   return $cfg->{os} || {};
}

sub _load_vars_ref {
   my $self = shift; my $args = $self->args; my $vars = $self->vars;

   exists $args->{o} or return; my $opts = $args->{o};

   for my $opt (ref $opts eq ARRAY ? @{ $opts } : ( $opts )) {
      my ($k, $v) = split m{ [=] }mx, $opt;

      if ($vars->{ $k }) {
         if (ref $vars->{ $k } eq ARRAY) { push @{ $vars->{ $k } }, $v }
         else { $vars->{ $k } = [ $vars->{ $k }, $v ] }
      }
      else { $vars->{ $k } = $v }
   }

   return;
}

sub _map_prompt_args {
   my ($self, $args) = @_;

   my %map = ( qw(-1 onechar -d default -e echo -p prompt) );

   for (keys %{ $args }) {
      exists $map{ $_ } and $args->{ $map{ $_ } } = delete $args->{ $_ };
   }

   return $args;
}

sub _print_fh {
   my ($self, $handle, $text) = @_;

   print {$handle} $text
      or $self->throw( error => 'IO error [_1]', args =>[ $ERRNO ] );
   return;
}

sub _raw_mode {
   my ($self, $handle) = @_; ReadMode q(raw), $handle; return;
}

sub _restore_mode {
   my ($self, $handle) = @_; ReadMode q(restore), $handle; return;
}

sub _set_attr {
   my ($self, $opt, $attr) = @_; my $v;

   exists $self->args->{ $opt } or return;

   if ($self->arglist =~ m{ $opt =s }mx) {
      $v = $self->args->{ $opt } and $self->$attr( $self->untaint_path( $v ) );
   }
   else { $self->$attr( TRUE ) }

   return;
}

# Private subroutines

sub __dont_ask {
   return exists $_[0]->{n} or exists $_[0]->{h} or exists $_[0]->{H};
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
   use base qw(Class::Usul::Programs);

   # In yourProg.pl
   use base qw(YourClass);

   exit YourClass->new( appclass => 'YourApplicationClass' )->dispatch;

=head1 Description

This base class provides methods common to command line programs. The
constructor can initialise a multi-lingual message catalog if required

=head1 Subroutines/Methods

=head2 new

   $self = Class::Usul::Programs->new({ ... })

Return a new program object. The optional argument is a hash ref which
may contain these attributes:

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

=head3 evar

Environment variable containing the path to a file which contains
the application installation directory. Defaults to the environment
variable <uppercase application name>_HOME

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

=head3 silent

Boolean which if true suppresses the usual started/finished
information messages. Defaults to false

=head2 add_leader

   $leader = $self->add_leader( $text, $args );

Prepend C<< $self->name >> to each line of C<$text>. If
C<< $args->{no_lead} >> exists then do nothing. Return C<$text> with
leader prepended

=head2 anykey

   $key = $self->anykey( $prompt );

Prompt string defaults to 'Press any key to continue...'. Calls and
returns L<prompt|/prompt>. Requires the user to press any key on the
keyboard (that generates a character response)

=head2 config

   $self = $self->config();

Return a reference to self

=head2 dispatch

   $rv = $self->dispatch;

Call the method specified by the C<-c> option on the command
line. Returns the exit code

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

=head2 get_debug_option

   $self->get_debug_option();

If it is an interactive session prompts the user to turn debugging
on. Returns true if debug is on. Also offers the option to quit

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

=head2 localize

   $local_text = $self->localize( $key, $args );

Localizes the message. Calls L<Class::Usul::I18N/localize>


=head2 output

   $self->output( $text, $args );

Calls L<Class::Usul::localize|Class::Usul/localize> with
the passed args. Adds the program leader and prints the result to
I<STDOUT>

=head2 prompt

   $line = $self->prompt( 'key' => 'value', ... );

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

=head2 usage

   $self->usage( $verbosity );

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

=head2 _bootstrap

Initialise the contents of the self referential hash

=head2 _get_control_chars

   ($cntrl, %cntrl) = $self->_get_control_chars( $handle );

Returns a string of pipe separated control characters and a hash of
symbolic names and values

=head2 _get_homedir

   $path = $self->_get_homedir( 'myApplication' );

Search through subdirectories of @INC looking for the file
myApplication.xml. Uses the location of this file to return the path to
the installation directory

=head2 _inflate

   $tempdir = $self->inflate( '__appldir(var/tmp)__' );

Inflates symbolic pathnames with their actual runtime values

=head2 _load_messages

=head2 _load_os_depends

=head2 _load_vars_ref

=head2 _new_log_object

=head2 _set_attr

Sets the specified attribute from the command line option

=head2 _raw_mode

   $self->_raw_mode( $handle );

Puts the terminal in raw input mode

=head2 _restore_mode

   $self->_restore_mode( $handle );

Restores line input mode to the terminal

=head1 Configuration and Environment

None

=head1 Diagnostics

Turning debug on produces some more output

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Class::I18N>

=item L<Class::Usul::InflateSymbols>

=item L<Getopt::Mixed>

=item L<IO::Interactive>

=item L<Term::ReadKey>

=item L<Text::Autoformat>

=item L<XML::Simple>

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
