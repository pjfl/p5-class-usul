package Class::Usul::Functions;

use 5.010001;
use strict;
use warnings;
use feature 'state';
use parent  'Exporter::Tiny';

use Class::Null;
use Class::Usul::Constants;
use Cwd                        qw( );
use Data::Printer      alias => q(_data_dumper), colored => 1, indent => 3,
    filters => { 'File::DataClass::IO' => sub { $_[ 0 ]->pathname },
                 'JSON::XS::Boolean'   => sub { q().$_[ 0 ]       }, };
use Digest                     qw( );
use Digest::MD5                qw( md5 );
use English                    qw( -no_match_vars );
use File::Basename             qw( basename dirname );
use File::DataClass::Functions qw( supported_extensions );
use File::DataClass::IO        qw( );
use File::HomeDir              qw( );
use File::Spec::Functions      qw( catdir catfile curdir );
use List::Util                 qw( first );
use Module::Runtime            qw( is_module_name require_module );
use Scalar::Util               qw( blessed openhandle );
use Sys::Hostname;
use Unexpected::Functions      qw( is_class_loaded PathAlreadyExists
                                   PathNotFound Tainted Unspecified );
use User::pwent;

our @EXPORT      = qw( is_member );
our @EXPORT_OK   = qw( abs_path app_prefix arg_list assert
                       assert_directory base64_decode_ns
                       base64_encode_ns bsonid bsonid_time bson64id
                       bson64id_time build class2appdir classdir
                       classfile create_token curry data_dumper distname
                       elapsed emit emit_err emit_to
                       ensure_class_loaded env_prefix escape_TT
                       exception find_apphome find_source first_char fold fqdn
                       fullname get_cfgfiles get_user hex2str
                       home2appldir io is_arrayref is_coderef
                       is_hashref is_win32 loginid
                       logname merge_attributes my_prefix pad
                       prefix2class product split_on__ split_on_dash
                       squeeze strip_leader sub_name sum symlink thread_id
                       throw throw_on_error trim unescape_TT
                       untaint_cmdline untaint_identifier untaint_path
                       untaint_string uuid zip );
our %EXPORT_REFS =   ( assert => sub { ASSERT } );
our %EXPORT_TAGS =   ( all => [ @EXPORT, @EXPORT_OK ], );

my $BSON_Id_Inc : shared = 0;

# Construction
sub _exporter_fail {
    my ($class, $name, $value, $globals) = @_;

    exists $EXPORT_REFS{ $name }
       and return ( $name => $EXPORT_REFS{ $name }->() );

    throw( error => 'Subroutine [_1] not found in package [_2]',
           args  => [ $name, $class ] );
}

# Public functions
sub abs_path ($) {
   my $y = shift; (defined $y and length $y) or return $y;

   (is_win32() or lc $OSNAME eq 'cygwin')
      and not -e $y and return untaint_path( $y ); # Hate

   $y = Cwd::abs_path( untaint_path( $y ) );

   is_win32() and defined $y and $y =~ s{ / }{\\}gmx; # More hate
   return $y;
}

sub app_prefix ($) {
   (my $y = lc ($_[ 0 ] || q())) =~ s{ :: }{_}gmx; return $y;
}

sub arg_list (;@) {
   return $_[ 0 ] && ref $_[ 0 ] eq 'HASH' ? { %{ $_[ 0 ] } }
        : $_[ 0 ]                          ? { @_ }
                                           : {};
}

sub assert_directory ($) {
   my $y = abs_path( $_[ 0 ] ); (defined $y and length $y) or return $y;

   return -d "${y}" ? $y : undef;
}

sub base64_decode_ns ($) {
   my $x = shift; defined $x or return; my @x = split q(), $x;

   my $index = _index64(); my $j = 0; my $k = 0;

   my $len = length $x; my $pad = 64; my @y = ();

 ROUND: {
    while ($j < $len) {
       my @c = (); my $i = 0;

       while ($i < 4) {
          my $uc = $index->[ ord $x[ $j++ ] ];

          $uc ne 'XX' and $c[ $i++ ] = 0 + $uc; $j == $len or next;

          if ($i < 4) {
             $i < 2 and last ROUND; $i == 2 and $c[ 2 ] = $pad; $c[ 3 ] = $pad;
          }

          last;
       }

      ($c[ 0 ]   == $pad || $c[ 1 ] == $pad) and last;
       $y[ $k++ ] = ( $c[ 0 ] << 2) | (($c[ 1 ] & 0x30) >> 4);
       $c[ 2 ]   == $pad and last;
       $y[ $k++ ] = (($c[ 1 ] & 0x0F) << 4) | (($c[ 2 ] & 0x3C) >> 2);
       $c[ 3 ]   == $pad and last;
       $y[ $k++ ] = (($c[ 2 ] & 0x03) << 6) | $c[ 3 ];
    }
 }

   return join q(), map { chr $_ } @y;
}

sub base64_encode_ns (;$) {
   my $x = shift; defined $x or return; my @x = split q(), $x;

   my $basis = _base64_char_set(); my $len = length $x; my @y = ();

   for (my $i = 0, my $j = 0; $len > 0; $len -= 3, $i += 3) {
      my $c1 = ord $x[ $i ]; my $c2 = $len > 1 ? ord $x[ $i + 1 ] : 0;

      $y[ $j++ ] = $basis->[ $c1 >> 2 ];
      $y[ $j++ ] = $basis->[ (($c1 & 0x3) << 4) | (($c2 & 0xF0) >> 4) ];

      if ($len > 2) {
         my $c3 = ord $x[ $i + 2 ];

         $y[ $j++ ] = $basis->[ (($c2 & 0xF) << 2) | (($c3 & 0xC0) >> 6) ];
         $y[ $j++ ] = $basis->[ $c3 & 0x3F ];
      }
      elsif ($len == 2) {
         $y[ $j++ ] = $basis->[ ($c2 & 0xF) << 2 ];
         $y[ $j++ ] = $basis->[ 64 ];
      }
      else { # len == 1
         $y[ $j++ ] = $basis->[ 64 ];
         $y[ $j++ ] = $basis->[ 64 ];
      }
   }

   return join q(), @y;
}

sub bsonid (;$) {
   return unpack 'H*', _bsonid( $_[ 0 ] );
}

sub bsonid_time ($) {
   return unpack 'N', substr hex2str( $_[ 0 ] ), 0, 4;
}

sub bson64id (;$) {
   return base64_encode_ns( _bsonid( 2 ) );
}

sub bson64id_time ($) {
   return unpack 'N', substr base64_decode_ns( $_[ 0 ] ), 2, 4;
}

sub build (&;$) {
   my $blck = shift; my $f = shift || sub {}; return sub { $blck->( $f->() ) };
}

sub class2appdir ($) {
   return lc distname( $_[ 0 ] );
}

sub classdir ($) {
   return catdir( split m{ :: }mx, $_[ 0 ] || q() );
}

sub classfile ($) {
   return catfile( split m{ :: }mx, $_[ 0 ].'.pm' );
}

sub create_token (;$) {
   my $seed = shift; my ($candidate, $digest); state $cache;

   if ($cache) { $digest = Digest->new( $cache ) }
   else {
      for (DIGEST_ALGORITHMS) {
         $candidate = $_; $digest = eval { Digest->new( $candidate ) } and last;
      }

      $digest or throw( 'Digest algorithm not found' ); $cache = $candidate;
   }

   $digest->add( $seed || join q(), time, rand 10_000, $PID, {} );

   return $digest->hexdigest;
}

sub curry (&$;@) {
   my ($code, @args) = @_; return sub { return $code->( @args, @_ ) };
}

sub data_dumper (;@) {
   _data_dumper( @_ ); return 1;
}

sub distname ($) {
   (my $y = $_[ 0 ] || q()) =~ s{ :: }{-}gmx; return $y;
}

#head2 downgrade
#   $sv_pv = downgrade $sv_pvgv;
#Horrendous Perl bug is promoting C<PV> and C<PVMG> type scalars to
#C<PVGV>. Serializing these values with L<Storable> throws a can't
#store SCALAR items error. This functions copies the string value of
#the input scalar to the output scalar but resets the output scalar
#type to C<PV>
#sub downgrade (;$) {
#   my $x = shift || q(); my ($y) = $x =~ m{ (.*) }msx; return $y;
#}

sub elapsed () {
   return time - $BASETIME;
}

sub emit (;@) {
   my @args = @_; $args[ 0 ] //= q(); chomp( @args );

   local ($OFS, $ORS) = ("\n", "\n");

   return openhandle *STDOUT ? emit_to( *STDOUT, @args ) : undef;
}

sub emit_err (;@) {
   my @args = @_; $args[ 0 ] //= q(); chomp( @args );

   local ($OFS, $ORS) = ("\n", "\n");

   return openhandle *STDERR ? emit_to( *STDERR, @args ) : undef;
}

sub emit_to ($;@) {
   my ($handle, @args) = @_; local $OS_ERROR;

   return (print {$handle} @args
           or throw( error => 'IO error: [_1]', args =>[ $OS_ERROR ] ));
}

sub ensure_class_loaded ($;$) {
   my ($class, $opts) = @_; $opts //= {};

   $class or throw( class => Unspecified,
                     args => [ 'class name' ], level => 2 );

   is_module_name( $class ) or throw( error => 'String [_1] invalid classname',
                                      args => [ $class ], level => 2 );

   not $opts->{ignore_loaded} and is_class_loaded( $class ) and return 1;

   eval { require_module( $class ) }; throw_on_error( { level => 3 } );

   is_class_loaded( $class )
      or throw( error => 'Class [_1] loaded but package undefined',
                args  => [ $class ], level => 2 );

   return 1;
}

sub env_prefix ($) {
   return uc app_prefix( $_[ 0 ] );
}

sub escape_TT (;$$) {
   my $y  = defined $_[ 0 ] ? $_[ 0 ] : q();
   my $fl = ($_[ 1 ] && $_[ 1 ]->[ 0 ]) || '<';
   my $fr = ($_[ 1 ] && $_[ 1 ]->[ 1 ]) || '>';

   $y =~ s{ \[\% }{${fl}%}gmx; $y =~ s{ \%\] }{%${fr}}gmx;

   return $y;
}

sub exception (;@) {
   return EXCEPTION_CLASS->caught( @_ );
}

sub find_apphome ($;$$) {
   my ($appclass, $default, $extns) = @_; my $path;

   # 0. Appclass false and pass the directory in (short circuit the search)
   not $appclass and $path = assert_directory $default and return $path;

   my $app_pref = app_prefix   $appclass;
   my $appdir   = class2appdir $appclass;
   my $classdir = classdir     $appclass;
   my $env_pref = env_prefix   $appclass;
   my $my_home  = File::HomeDir->my_home;

   # 1a.   Environment variable - for application directory
   $path = assert_directory $ENV{ "${env_pref}_HOME" } and return $path;
   # 1b.   Environment variable - for config file
   $path = _get_env_var_for_conf( "${env_pref}_CONFIG" ) and return $path;
   # 2a.   Users XDG_DATA_HOME env variable or XDG default share directory
   $path = $ENV{ 'XDG_DATA_HOME' } || catdir( $my_home, '.local', 'share' );
   $path = assert_directory catdir( $path, $appdir ) and return $path;
   # 2b.   Users home directory - dot file containing shell env variable
   $path = _get_dot_file_var( $my_home, $app_pref, $classdir ) and return $path;
   # 2c.   Users home directory - dot directory is apphome
   $path = catdir( $my_home, ".${app_pref}" );
   $path = assert_directory $path and return $path;
   # 3.    Well known path containing shell env file
   $path = _get_known_file_var( $appdir, $classdir ) and return $path;
   # 4.    Default install prefix
   $path = catdir( @{ PREFIX() }, $appdir, qw( default lib ), $classdir );
   $path = assert_directory $path and return $path;
   # 5a.   Config file found in @INC - underscore as separator
   $path = _find_conf_in_inc( $classdir, $app_pref, $extns ) and return $path;
   # 5b.   Config file found in @INC - dash as separator
   $path = _find_conf_in_inc( $classdir, $appdir, $extns ) and return $path;
   # 6.    Pass the default in
   $path = assert_directory $default and return $path;
   # 7.    Default to /tmp
   return  untaint_path( DEFAULT_CONFHOME );
}

sub find_source ($) {
   my $class = shift; my $file = classfile( $class ); my $path;

   for (@INC) {
      $path = abs_path( catfile( $_, $file ) ) and -f $path and return $path;
   }

   return;
}

sub first_char ($) {
   return substr $_[ 0 ], 0, 1;
}

sub fold (&) {
   my $f = shift;

   return sub (;$) {
      my $x = shift;

      return sub (;@) {
         my $y = $x; $y = $f->( $y, shift ) while (@_); return $y;
      }
   }
}

sub fqdn (;$) {
   my $x = shift || hostname; return (gethostbyname( $x ))[ 0 ];
}

sub fullname () {
   my $y = (split m{ \s* , \s * }msx, (get_user()->gecos || q()))[ 0 ];

   $y =~ s{ [\&] }{}gmx; # Because af25e158-d0c7-11e3-bdcb-31d9eda79835

   return untaint_cmdline( $y || q());
}

sub get_cfgfiles ($;$$) {
   my ($appclass, $dirs, $extns) = @_;

   $appclass // throw( class => Unspecified, args => [ 'application class' ],
                       level => 2 );
   is_arrayref( $dirs ) or $dirs = [ $dirs // curdir ];

   my $app_pref = app_prefix   $appclass;
   my $appdir   = class2appdir $appclass;
   my $env_pref = env_prefix   $appclass;
   my $suffix   = $ENV{ "${env_pref}_CONFIG_LOCAL_SUFFIX" } || '_local';
   my @paths    = ();

   for my $dir (@{ $dirs }) {
      for my $extn (@{ $extns || [ supported_extensions() ] }) {
         for my $path (map { _catpath( $dir, $_ ) } "${app_pref}${extn}",
                       "${appdir}${extn}", "${app_pref}${suffix}${extn}",
                       "${appdir}${suffix}${extn}") {
            -f $path and push @paths, $path;
         }
      }
   }

   return \@paths;
}

sub get_user (;$) {
   return is_win32() ? Class::Null->new : getpwuid( shift // $UID );
}

sub hex2str (;$) {
   my @a = split m{}mx, shift // q(); my $str = q();

   while (my ($x, $y) = splice @a, 0, 2) { $str .= pack 'C', hex "${x}${y}" }

   return $str;
}

sub home2appldir ($) {
   $_[ 0 ] or return; my $dir = io( $_[ 0 ] );

   $dir = $dir->parent while ($dir ne $dir->parent and $dir !~ m{ lib \z }mx);

   return $dir ne $dir->parent ? $dir->parent : undef;
}

sub io (;@) {
   return File::DataClass::IO->new( @_ );
}

sub is_arrayref (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq 'ARRAY' ? 1 : 0;
}

sub is_coderef (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq 'CODE' ? 1 : 0;
}

sub is_hashref (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq 'HASH' ? 1 : 0;
}

sub is_member (;@) {
   my ($candidate, @args) = @_; $candidate or return;

   is_arrayref $args[ 0 ] and @args = @{ $args[ 0 ] };

   return (first { $_ eq $candidate } @args) ? 1 : 0;
}

sub is_win32 () {
   return lc $OSNAME eq EVIL ? 1 : 0;
}

sub loginid (;$) {
   return untaint_cmdline( get_user( $_[ 0 ] )->name || 'unknown' );
}

sub logname () {
   return untaint_cmdline( $ENV{USER} || $ENV{LOGNAME} || loginid() );
}

sub merge_attributes ($$$;$) {
   my ($dest, $src, $defaults, $attrs) = @_; my $class = blessed $src;

   for (grep { not exists $dest->{ $_ } or not defined $dest->{ $_ } }
        @{ $attrs || [] }) {
      my $v = $class ? ($src->can( $_ ) ? $src->$_() : undef) : $src->{ $_ };

      defined $v or $v = $defaults->{ $_ }; defined $v and $dest->{ $_ } = $v;
   }

   return $dest;
}

sub my_prefix (;$) {
   return split_on__( basename( $_[ 0 ] || q(), EXTNS ) );
}

sub pad ($$;$$) {
   my ($x, $length, $str, $direction) = @_;

   my $x_len = length $x; $x_len >= $length and return $x;
   my $pad   = substr( ((defined $str && length $str ? $str : q( ))
                        x ($length - $x_len)), 0, $length - $x_len );

   (not $direction or $direction eq 'right') and return $x.$pad;
   $direction eq 'left' and return $pad.$x;

   return (substr $pad, 0, int( (length $pad) / 2 )).$x
         .(substr $pad, 0, int( 0.99999999 + (length $pad) / 2 ));
}

sub prefix2class (;$) {
   return join '::', map { ucfirst } split m{ - }mx, my_prefix( $_[ 0 ] );
}

sub product (;@) {
   return ((fold { $_[ 0 ] * $_[ 1 ] })->( 1 ))->( @_ );
}

sub split_on__ (;$$) {
   return (split m{ _ }mx, $_[ 0 ] || q())[ $_[ 1 ] || 0 ];
}

sub split_on_dash (;$$) {
   return (split m{ \- }mx, $_[ 0 ] || q())[ $_[ 1 ] || 0 ];
}

sub squeeze (;$) {
   (my $y = $_[ 0 ] || q()) =~ s{ \s+ }{ }gmx; return $y;
}

sub strip_leader (;$) {
   (my $y = $_[ 0 ] || q()) =~ s{ \A [^:]+ [:] \s+ }{}msx; return $y;
}

sub sub_name (;$) {
   my $x = $_[ 0 ] || 0;

   return (split m{ :: }mx, ((caller ++$x)[ 3 ]) || 'main')[ -1 ];
}

sub sum (;@) {
   return ((fold { $_[ 0 ] + $_[ 1 ] })->( 0 ))->( @_ );
}

sub symlink (;$$$) {
   my ($from, $to, $base) = @_;

   defined $base and not CORE::length $base and $base = File::Spec->rootdir;
   $from or throw( class => Unspecified, args => [ 'path from' ] );
   $from = io( $from )->absolute( $base );
   $from->exists or throw( class => PathNotFound, args => [ "${from}" ] );
   $to   or throw( class => Unspecified, args => [ 'path to' ] );
   $to   = io( $to   )->absolute( $base ); $to->is_link and $to->unlink;
   $to->exists  and throw( class => PathAlreadyExists, args => [ "${to}" ] );
   CORE::symlink "${from}", "${to}"
      or throw( error => 'Symlink from [_1] to [_2] failed: [_3]',
                args  => [ "${from}", "${to}", $OS_ERROR ] );
   return "Symlinked ${from} to ${to}";
}

sub thread_id {
   return exists $INC{ 'threads.pm' } ? threads->tid() : 0;
}

sub throw (;@) {
   EXCEPTION_CLASS->throw( @_ );
}

sub throw_on_error (;@) {
   EXCEPTION_CLASS->throw_on_error( @_ );
}

sub trim (;$$) {
   my $c = $_[ 1 ] || " \t"; (my $y = $_[ 0 ] || q()) =~ s{ \A [$c]+ }{}mx;

   chomp $y; $y =~ s{ [$c]+ \z }{}mx; return $y;
}

sub unescape_TT (;$$) {
   my $y  = defined $_[ 0 ] ? $_[ 0 ] : q();
   my $fl = ($_[ 1 ] && $_[ 1 ]->[ 0 ]) || '<';
   my $fr = ($_[ 1 ] && $_[ 1 ]->[ 1 ]) || '>';

   $y =~ s{ ${fl}\% }{[%}gmx; $y =~ s{ \%${fr} }{%]}gmx;

   return $y;
}

sub untaint_cmdline (;$) {
   return untaint_string( UNTAINT_CMDLINE, $_[ 0 ] );
}

sub untaint_identifier (;$) {
   return untaint_string( UNTAINT_IDENTIFIER, $_[ 0 ] );
}

sub untaint_path (;$) {
   return untaint_string( UNTAINT_PATH, $_[ 0 ] );
}

sub untaint_string ($;$) {
   my ($regex, $string) = @_;

   defined $string or return; length $string or return q();

   my ($untainted) = $string =~ $regex;

   (defined $untainted and $untainted eq $string)
      or throw( class => Tainted, args => [ $string ], level => 3 );

   return $untainted;
}

sub uuid {
   return io( $_[ 0 ] || UUID_PATH )->lock->chomp->getline;
}

sub zip (@) {
   my $p = @_ / 2; return @_[ map { $_, $_ + $p } 0 .. $p - 1 ];
}

# Private functions
sub _base64_char_set () {
   return [ 0 .. 9, 'A' .. 'Z', '_', 'a' .. 'z', '~', '+' ];
}

sub _bsonid (;$) {
   my $version = shift;
   my $now     = time;
   my $time    = _bsonid_time( $now, $version );
   my $host    = substr md5( hostname ), 0, 3;
   my $pid     = pack 'n', $$ % 0xFFFF;

   return $time.$host.$pid._bsonid_inc( $now, $version );
}

sub _bsonid_inc ($;$) {
   my ($now, $version) = @_; state $id_inc //= 0; state $prev_time //= 0;

   $version or return substr pack( 'N', $BSON_Id_Inc++ % 0xFFFFFF ), 1, 3;

   $id_inc++; $now > $prev_time and $id_inc = 0; $prev_time = $now;

   $version < 2 and return (substr pack( 'n', thread_id() % 0xFF ), 1, 1)
                          .(pack 'n', $id_inc % 0xFFFF);

   $version < 3 and return (pack 'n', thread_id() % 0xFFFF )
                          .(pack 'n', $id_inc % 0xFFFF);

   return (pack 'n', thread_id() % 0xFFFF )
         .(substr pack( 'N', $id_inc % 0xFFFFFF ), 1, 3);
}

sub _bsonid_time ($;$) {
   my ($now, $version) = @_;

   (not $version or $version < 2) and return pack 'N', $now;

   $version < 3 and return (substr pack( 'N', $now >> 32 ), 2, 2)
                          .(pack 'N', $now % 0xFFFFFFFF);

   return (pack 'N', $now >> 32).(pack 'N', $now % 0xFFFFFFFF);
}

sub _catpath {
   return untaint_path( catfile( @_ ) );
}

sub _find_conf_in_inc {
   my ($classdir, $file, $extns) = @_;

   for my $dir (map { catdir( abs_path( $_ ), $classdir ) } @INC) {
      for my $extn (@{ $extns || [ supported_extensions() ] }) {
         my $path = _catpath( $dir, $file.$extn );

         -f $path and return dirname( $path );
      }
   }

   return;
}

sub _get_dot_file_var {
   my ($dir, $file, $classdir) = @_;

   my $path; $path = _read_variable( $dir, ".${file}", 'APPLDIR' )
         and $path = catdir( $path, 'lib', $classdir );

   return $path = assert_directory $path ? $path : undef;
}

sub _get_env_var_for_conf {
   my $file = $ENV{ ($_[ 0 ] || return) };
   my $path = $file ? dirname( $file ) : NUL;

   return $path = assert_directory $path ? $path : undef;
}

sub _get_known_file_var {
   my ($appname, $classdir) = @_; my $path; $appname || return;

   $path = _read_variable( DEFAULT_ENVDIR(), $appname, 'APPLDIR' );
   $path and $path = catdir( $path, 'lib', $classdir );

   return $path = assert_directory $path ? $path : undef;
}

sub _index64 () {
   return [ qw(XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX 64  XX XX XX XX
                0  1  2  3   4  5  6  7   8  9 XX XX  XX XX XX XX
               XX 10 11 12  13 14 15 16  17 18 19 20  21 22 23 24
               25 26 27 28  29 30 31 32  33 34 35 XX  XX XX XX 36
               XX 37 38 39  40 41 42 43  44 45 46 47  48 49 50 51
               52 53 54 55  56 57 58 59  60 61 62 XX  XX XX 63 XX

               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX) ];
}

sub _read_variable {
   my ($dir, $file, $variable) = @_; my $path;

  ($dir and $file and $variable) or return;
   is_arrayref( $dir ) and $dir = catdir( @{ $dir } );
   $path = io( _catpath( $dir, $file ) )->chomp;
  ($path->exists and $path->is_file) or return;

   return first   { length }
          map     { trim( (split '=', $_)[ 1 ] ) }
          grep    { m{ \A \s* $variable \s* [=] }mx }
          reverse $path->getlines;
}

1;

__END__

=pod

=head1 Name

CatalystX::Usul::Functions - Globally accessible functions

=head1 Synopsis

   package MyBaseClass;

   use CatalystX::Usul::Functions;

=head1 Description

Provides globally accessible functions

=head1 Subroutines/Methods

=head2 abs_path

   $absolute_untainted_path = abs_path $some_path;

Untaints path. Makes it an absolute path and returns it. Returns undef
otherwise. Traverses the filesystem

=head2 app_prefix

   $prefix = app_prefix __PACKAGE__;

Takes a class name and returns it lower cased with B<::> changed to
B<_>, e.g. C<App::Munchies> becomes C<app_munchies>

=head2 arg_list

   $args = arg_list @rest;

Returns a hash ref containing the passed parameter list. Enables
methods to be called with either a list or a hash ref as it's input
parameters

=head2 assert

   assert $ioc_object, $condition, $message;

By default does nothing. Does not evaluate the passed parameters. The
L<assert|Classs::Usul::Constants/ASSERT> constant can be set via
an inherited class attribute to do something useful with whatever parameters
are passed to it

=head2 assert_directory

   $untainted_path = assert_directory $path_to_directory;

Untaints directory path. Makes it an absolute path and returns it if it
exists. Returns undef otherwise

=head2 base64_decode_ns

   $decoded_value = base64_decode_ns $encoded_value;

Decode a scalar value encode using L<base64_encode_ns>

=head2 base64_encode_ns

   $encoded_value = base64_encode_ns $encoded_value;

Base 64 encode a scalar value using an output character set that preserves
the input values sort order (natural sort)

=head2 bsonid

   $bson_id = bsonid;

Generate a new C<BSON> id. Returns a 24 character string of hex digits that
are reasonably unique across hosts and are in ascending order. Use this
to create unique ids for data streams like message queues and file feeds

=head2 bsonid_time

   $seconds_elapsed_since_the_epoch = bsonid_time $bson_id;

Returns the time the C<BSON> id was generated as Unix time

=head2 bson64id

   $base64_encoded_extended_bson64_id = bson64id;

Like L</bsonid> but better thread long running process support. A custom
Base64 encoding is used to reduce the id length

=head2 bson64id_time

   $seconds_elapsed_since_the_epoch = bson64id_time $bson64_id;

Returns the time the C<BSON64> id was generated as Unix time

=head2 build

   $code_ref = build { }, $code_ref;

Returns a code ref which when called returns the result of calling the block
passing in the result of calling the optional code ref. Delays the calling
of the input code ref until the output code ref is called

=head2 class2appdir

   $appdir = class2appdir __PACKAGE__;

Returns lower cased L</distname>, e.g. C<App::Munchies> becomes
C<app-munchies>

=head2 classdir

   $dir_path = classdir __PACKAGE__;

Returns the path (directory) of a given class. Like L</classfile> but
without the I<.pm> extension

=head2 classfile

   $file_path = classfile __PACKAGE__ ;

Returns the path (file name plus extension) of a given class. Uses
L<File::Spec> for portability, e.g. C<App::Munchies> becomes
C<App/Munchies.pm>

=head2 create_token

   $random_hex = create_token $seed;

Create a random string token using the first available L<Digest>
algorithm. If C<$seed> is defined then add that to the digest,
otherwise add some random data. Returns a hexadecimal string

=head2 curry

   $curried_code_ref = curry $code_ref, @args;
   $result = $curried_code_ref->( @more_args );

Returns a subroutine reference which when called, calls and returns the
initial code reference passing in the original argument list and the
arguments from the curried call. Must be called with a code reference and
at least one argument

=head2 data_dumper

   data_dumper $thing;

Uses L<Data::Printer> to dump C<$thing> in colour to I<stderr>

=head2 distname

   $distname = distname __PACKAGE__;

Takes a class name and returns it with B<::> changed to
B<->, e.g. C<App::Munchies> becomes C<App-Munchies>

=head2 elapsed

   $elapsed_seconds = elapsed;

Returns the number of seconds elapsed since the process started

=head2 emit

   emit @lines_of_text;

Prints to I<STDOUT> the lines of text passed to it. Lines are C<chomp>ed
and then have newlines appended. Throws on IO errors

=head2 emit_err

   emit_err @lines_of_text;

Like L</emit> but output to C<STDERR>

=head2 emit_to

   emit_to $filehandle, @lines_of_text;

Prints to the specified file handle

=head2 ensure_class_loaded

   ensure_class_loaded $some_class, $options_ref;

Require the requested class, throw an error if it doesn't load

=head2 env_prefix

   $prefix = env_prefix $class;

Returns upper cased C<app_prefix>. Suitable as prefix for environment
variables

=head2 escape_TT

   $text = escape_TT '[% some_stash_key %]';

The left square bracket causes problems in some contexts. Substitute a
less than symbol instead. Also replaces the right square bracket with
greater than for balance. L<Template::Toolkit> will work with these
sequences too, so unescaping isn't absolutely necessary

=head2 exception

   $e = exception $error;

Expose the C<catch> method in the exception
class L<CatalystX::Usul::Exception>. Returns a new error object

=head2 find_apphome

   $directory_path = find_apphome $appclass, $homedir, $extns

Returns the path to the applications home directory. Searches the following:

   # 0.  Undef appclass and pass the directory in (short circuit the search)
   # 1a. Environment variable - for application directory
   # 1b. Environment variable - for config file
   # 2a. Users XDG_DATA_HOME env variable or XDG default share directory
   # 2b. Users home directory - dot file containing shell env variable
   # 2c. Users home directory - dot directory is apphome
   # 3.  Well known path containing shell env file
   # 4.  Default install prefix
   # 5a. Config file found in @INC - underscore as separator
   # 5b. Config file found in @INC - dash as separator
   # 6.  Pass the default in
   # 7.  Default to /tmp

=head2 find_source

   $path = find_source $module_name;

Find absolute path to the source code for the given module

=head2 first_char

   $single_char = first_char $some_string;

Returns the first character of C<$string>

=head2 fold

   *sum = fold { $a + $b } 0;

Classic reduce function with optional base value

=head2 fqdn

   $domain_name = fqdn $hostname;

Call C<gethostbyname> on the supplied hostname whist defaults to this host

=head2 fullname

   $fullname = fullname;

Returns the untainted first sub field from the gecos attribute of the
object returned by a call to L</get_user>. Returns the null string if
the gecos attribute value is false

=head2 get_cfgfiles

   $paths = get_cfgfiles $appclass, $dirs, $extns

Returns an array ref of configurations file paths for the application

=head2 get_user

   $user_object = get_user $optional_uid;

Returns the user object from a call to C<getpwuid> with get L<User::pwent>
package loaded. On MSWin32 systems returns an instance of L<Class::Null>.
Defaults to the current uid but will lookup the supplied uid if provided

=head2 hex2str

   $string = hex2str $pairs_of_hex_digits;

Converts the pairs of hex digits into a string of characters

=head2 home2appldir

   $appldir = home2appldir $home_dir;

Strips the trailing C<lib/my_package> from the supplied directory path

=head2 io

   $io_object_ref = io $path_to_file_or_directory;

Returns a L<File::DataClass::IO> object reference

=head2 is_arrayref

   $bool = is_arrayref $scalar_variable

Tests to see if the scalar variable is an array ref

=head2 is_coderef

   $bool = is_coderef $scalar_variable

Tests to see if the scalar variable is a code ref

=head2 is_hashref

   $bool = is_hashref $scalar_variable

Tests to see if the scalar variable is a hash ref

=head2 is_member

   $bool = is_member 'test_value', qw( a_value test_value b_value );

Tests to see if the first parameter is present in the list of
remaining parameters

=head2 is_win32

   $bool = is_win32;

Returns true if the C<$OSNAME> is L<evil|Class::Usul::Constants/EVIL>

=head2 loginid

   $loginid = loginid;

Returns the untainted name attribute of the object returned by a call
to L</get_user> or 'unknown' if the name attribute value is false

=head2 logname

   $logname = logname;

Returns untainted the first true value returned by; the environment
variable C<USER>, the environment variable C<LOGNAME>, and the
function L</loginid>

=head2 merge_attributes

   $dest = merge_attributes $dest, $src, $defaults, $attr_list_ref;

Merges attribute hashes. The C<$dest> hash is updated and returned. The
C<$dest> hash values take precedence over the C<$src> hash values which
take precedence over the C<$defaults> hash values. The C<$src> hash
may be an object in which case its accessor methods are called

=head2 my_prefix

   $prefix = my_prefix $PROGRAM_NAME;

Takes the basename of the supplied argument and returns the first _
(underscore) separated field. Supplies basename with
L<extensions|Class::Usul::Constants/EXTNS>

=head2 pad

   $padded_str = pad $unpadded_str, $wanted_length, $pad_char, $direction;

Pad a string out to the wanted length with the C<$pad_char> which
defaults to a space. Direction can be; I<both>, I<left>, or I<right>
and defaults to I<right>

=head2 prefix2class

   $class = prefix2class $PROGRAM_NAME;

Calls L</my_prefix> with the supplied argument, splits the result on dash,
C<ucfirst>s the list and then C<join>s that with I<::>

=head2 product

   $product = product 1, 2, 3, 4;

Returns the product of the list of numbers

=head2 split_on__

   $field = split_on__ $string, $field_no;

Splits string by _ (underscore) and returns the requested field. Defaults
to field zero

=head2 split_on_dash

   $field = split_on_dash $string, $field_no;

Splits string by - (dash) and returns the requested field. Defaults
to field zero

=head2 squeeze

   $string = squeeze $string_containing_muliple_spacesd;

Squeezes multiple whitespace down to a single space

=head2 strip_leader

   $stripped = strip_leader 'my_program: Error message';

Strips the leading "program_name: whitespace" from the passed argument

=head2 sub_name

   $sub_name = sub_name $level;

Returns the name of the method that calls it

=head2 sum

   $total = sum 1, 2, 3, 4;

Adds the list of values

=head2 symlink

   $message = symlink $from, $to, $base;

It creates a symlink. If either C<$from> or C<$to> is a relative path
then C<$base> is prepended to make it absolute. Returns a message
indicating success or throws an exception on failure

=head2 thread_id

   $tid = thread_id;

Returns the id of this thread. Returns zero if threads are not loaded

=head2 throw

   throw error => 'error_key', args => [ 'error_arg' ];

Expose L<Class::Usul::Exception/throw>. L<Class::Usul::Constants> has a
class attribute I<Exception_Class> which can be set change the class
of the thrown exception

=head2 throw_on_error

   throw_on_error @args;

Passes it's optional arguments to L</exception> and if an exception object is
returned it throws it. Returns undefined otherwise. If no arguments are
passed L</exception> will use the value of the global C<$EVAL_ERROR>

=head2 trim

   $trimmed_string = trim $string_with_leading_and_trailing_whitespace;

Remove leading and trailing whitespace including trailing newlines. Takes
an additional string used as the character class to remove. Defaults to
space and tab

=head2 unescape_TT

   $text = unescape_TT '<% some_stash_key %>';

Do the reverse of C<escape_TT>

=head2 untaint_cmdline

   $untainted_cmdline = untaint_cmdline $maybe_tainted_cmdline;

Returns an untainted command line string. Calls L</untaint_string> with the
matching regex from L<CatalystX::Usul::Constants>

=head2 untaint_identifier

   $untainted_identifier = untaint_identifier $maybe_tainted_identifier;

Returns an untainted identifier string. Calls L</untaint_string> with the
matching regex from L<CatalystX::Usul::Constants>

=head2 untaint_path

   $untainted_path = untaint_path $maybe_tainted_path;

Returns an untainted file path. Calls L</untaint_string> with the
matching regex from L<CatalystX::Usul::Constants>

=head2 untaint_string

   $untainted_string = untaint_string $regex, $maybe_tainted_string;

Returns an untainted string or throws

=head2 uuid

   $uuid = uuid( $optional_uuid_proc_filesystem_path );

Return the contents of F</proc/sys/kernel/random/uuid>

=head2 zip

   %hash = zip @list_of_keys, @list_of_values;

Zips two list of equal size together to form a hash

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<CatalystX::Usul::Constants>

=item L<Data::Printer>

=item L<Digest>

=item L<File::HomeDir>

=item L<List::Util>

=back

=head1 Incompatibilities

The L</home2appldir> method is dependent on the installation path
containing a B<lib>

The L</uuid> method with only work on a OS with a F</proc> filesystem

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

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
