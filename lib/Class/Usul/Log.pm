package Class::Usul::Log;

use namespace::autoclean;

use Class::Null;
use Class::Usul::Constants qw( FALSE LOG_LEVELS NUL SPC TRUE );
use Class::Usul::Functions qw( is_hashref is_member merge_attributes
                               untaint_identifier );
use Class::Usul::Types     qw( Bool DataEncoding HashRef
                               LoadableClass Logger Undef );
use Encode                 qw( encode );
use File::Basename         qw( dirname );
use File::DataClass::Types qw( Path );
use Scalar::Util           qw( blessed );
use Sub::Install           qw( install_sub );
use Moo;

# Construction
my $_build_log = sub {
   my $self = shift; my $attr = $self->get_log_attributes;

   return $attr ? $self->_log_class->new( %{ $attr } ) : Class::Null->new;
};

# Private attributes
has '_debug_flag'     => is => 'ro',   isa => Bool, default => FALSE,
   init_arg           => 'debug';

has '_encoding'       => is => 'ro',   isa => DataEncoding | Undef,
   init_arg           => 'encoding';

has '_log'            => is => 'lazy', isa => Logger, builder => $_build_log,
   init_arg           => 'log';

has '_log_attributes' => is => 'ro',   isa => HashRef, default => sub { {} },
   init_arg           => 'log_attributes';

has '_log_class'      => is => 'lazy', isa => LoadableClass, coerce => TRUE,
   default            => 'Log::Handler', init_arg => 'log_class';

has '_logfile'        => is => 'ro',   isa => Path | Undef, coerce => TRUE,
   init_arg           => 'logfile';

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $class, @args) = @_; my $attr = $orig->( $class, @args );

   my $builder = delete $attr->{builder} or return $attr;
   my $config  = $builder->can( 'config' ) ? $builder->config : {};
   my $cfgattr = [ qw( encoding log_attributes log_class logfile ) ];

   merge_attributes $attr, $builder, {}, [ 'debug' ];
   merge_attributes $attr, $config,  {}, $cfgattr;

   return $attr;
};

my $_add_methods = sub {
   my ($class, @methods) = @_;

   for my $method (@methods) {
      $class->can( $method )
         or install_sub { into => $class, as => $method, code => sub {
            my ($self, $text, $opts) = @_; $text or return FALSE;

            $text = ucfirst "${text}"; chomp $text; $text .= "\n";

            if (defined $opts) {
               my $lead = ucfirst $opts->{leader} // NUL;
               my $user = $opts->{user} ? '['.$opts->{user}->username.'] '
                        :         $lead ? SPC
                                        : NUL;

               $text = "${lead}${user}${text}";
            }

            $self->_encoding and $text = encode( $self->_encoding, $text );
            $self->_log->$method( $text );
            return TRUE;
         } };
   }

   return;
};

$_add_methods->( __PACKAGE__, LOG_LEVELS );

# Public methods
sub filehandle {
   my $self = shift; $self->_log_class eq 'Log::Handler' or return;

   return $self->_log->output( 'file-out' )->{fh};
}

sub get_log_attributes {
   my $self = shift; my $attr = { %{ $self->_log_attributes } };

   $self->_log_class eq 'Log::Handler' or return $attr;

   my $fattr   = $attr->{file} //= {};
   my $logfile = $fattr->{filename} // $self->_logfile;

   ($logfile and -d dirname( "${logfile}" )) or return $attr;

   $fattr->{alias   } = 'file-out';
   $fattr->{filename} = "${logfile}";
   $fattr->{maxlevel} = $self->_debug_flag ? 'debug'
                      : untaint_identifier $fattr->{maxlevel} // 'info';
   $fattr->{mode    } = untaint_identifier $fattr->{mode    } // 'append';
   return $attr;
}

sub log {
   my ($self, @args) = @_;

   my $args  = (is_hashref $args[ 0 ]) ? $args[ 0 ] : { @args };
   my $level = $args->{level};

   is_member $level, LOG_LEVELS and return $self->$level( $args->{message} );

   return;
}

1;

__END__

=pod

=head1 Name

Class::Usul::Log - Create methods for each logging level that encode their output

=head1 Synopsis

   use Class::Usul::Log;
   use File::DataClass::IO;

   my $file = io [ 't', 'test.log' ];
   my $log  = Class::Usul::Log->new( encoding => 'UTF-8', logfile => $file );
   my $text = 'Your error message goes here';

   # Can now call the following. The text will be encoded UTF-8
   $log->debug( $text ); # Does not log as debug was not true in the constructor
   $log->info ( $text );
   $log->warn ( $text );
   $log->error( $text );
   $log->alert( $text );
   $log->fatal( $text );

=head1 Description

Creates methods for each logging level that encode their output. The
logging levels are defined by the
L<log levels|Class::Usul::Constants/LOG_LEVELS> constant

=head1 Configuration and Environment

Defines the following attributes

=over 3

=item C<debug>

Debug flag defaults to false. If set to true calls to log at the debug level
will succeed rather than being ignored

=item C<encoding>

Optional output encoding. If present output to the logfile is encoded

=item C<log>

Optional log object. Will instantiate an instance of L<Log::Handler> if this
is not provided

=item C<log_attributes>

Attributes used to create the log object

=item C<log_class>

The classname of the log object. This is loaded on demand

=item C<logfile>

Path to the logfile

=back

=head1 Subroutines/Methods

=head2 C<BUILDARGS>

Monkey with the constructors signature

=head2 C<filehandle>

Return the loggers file handle. This was added for L<IO::Async>, so that we
can tell it not to close the log file handle when it forks a child process

=head2 C<get_log_attributes>

Returns the hash reference passed to the constructor of the log class. Returns
C<undef> to indicate no logging, an instance of L<Class::Null> is used instead

=head2 C<log>

   $self->log( { level => $level, message => $message } );

Logs the message at the given level

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Null>

=item L<Moo>

=item L<Encode>

=item L<File::DataClass>

=item L<Log::Handler>

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
