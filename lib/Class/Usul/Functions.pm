# @(#)$Id$

package Class::Usul::Functions;

use strict;
use warnings;
use feature      qw(state);
use version; our $VERSION = qv( sprintf '0.8.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Constants;
use Data::Printer alias => q(Dumper), colored => 1, indent => 3,
    filters => { 'File::DataClass::IO' => sub { $_[ 0 ]->pathname }, };
use Cwd          qw();
use Digest       qw();
use Digest::MD5  qw(md5);
use English      qw(-no_match_vars);
use File::Basename ();
use File::Spec;
use List::Util   qw(first);
use Path::Class::Dir;
use Scalar::Util qw(blessed openhandle);
use Sys::Hostname;

my @_functions; my $_bson_id_inc : shared = 0;

BEGIN {
   @_functions = ( qw(abs_path app_prefix arg_list assert_directory
                      bsonid bsonid_time class2appdir classdir
                      classfile create_token data_dumper distname
                      downgrade elapsed env_prefix escape_TT exception
                      find_source fold hex2str home2appldir is_arrayref
                      is_coderef is_hashref is_member merge_attributes
                      my_prefix prefix2class product say split_on__
                      squeeze strip_leader sub_name sum throw trim
                      unescape_TT untaint_cmdline untaint_identifier
                      untaint_path untaint_string zip) );
}

use Sub::Exporter -setup => {
   exports => [ @_functions, assert => sub { ASSERT } ],
   groups  => { default => [ qw(is_member) ], },
};

sub abs_path ($) {
   return $_[ 0 ] ? Cwd::abs_path( untaint_path( $_[ 0 ] )) : $_[ 0 ];
}

sub app_prefix ($) {
   (my $y = lc ($_[ 0 ] || q())) =~ s{ :: }{_}gmx; return $y;
}

sub arg_list (;@) {
   return $_[ 0 ] && ref $_[ 0 ] eq q(HASH) ? { %{ $_[ 0 ] } }
        : $_[ 0 ]                           ? { @_ }
                                            : {};
}

sub assert_directory ($) {
   my $y = abs_path( $_[ 0 ] ) or return; return -d $y ? $y : undef;
}

sub bsonid () {
   my $time = pack 'N', time;
   my $host = substr md5( hostname ), 0, 3;
   my $proc = pack 'n', $$ % 0xFFFF;
   my $inc  = substr pack( 'N', $_bson_id_inc++ % 0xFFFFFF ), 1, 3;

   return unpack 'H*', $time.$host.$proc.$inc;
}

sub bsonid_time ($) {
   return unpack 'N', substr hex2str( shift ), 0, 4;
}

sub class2appdir ($) {
   return lc distname( $_[ 0 ] );
}

sub classdir ($) {
   return File::Spec->catdir( split m{ :: }mx, $_[ 0 ] );
}

sub classfile ($) {
   return File::Spec->catfile( split m{ :: }mx, $_[ 0 ].q(.pm) );
}

sub create_token (;$) {
   my $seed = shift; my ($candidate, $digest); state $cache;

   if ($cache) { $digest = Digest->new( $cache ) }
   else {
      for (DIGEST_ALGORITHMS) {
         $candidate = $_; $digest = eval { Digest->new( $candidate ) } and last;
      }

      $digest or throw( 'No digest algorithm' ); $cache = $candidate;
   }

   $digest->add( $seed || join q(), time, rand 10_000, $PID, {} );

   return $digest->hexdigest;
}

sub data_dumper (;@) {
   Dumper( @_ ); return 1;
}

sub distname ($) {
   (my $y = $_[ 0 ] || q()) =~ s{ :: }{-}gmx; return $y;
}

sub downgrade (;$) {
   my $x = shift || q(); my ($y) = $x =~ m{ (.*) }msx; return $y;
}

sub elapsed () {
   return time - $BASETIME;
}

sub env_prefix ($) {
   return uc app_prefix( $_[ 0 ] );
}

sub escape_TT (;$$) {
   my $y  = defined $_[ 0 ] ? $_[ 0 ] : q();
   my $fl = ($_[ 1 ] && $_[ 1 ]->[ 0 ]) || q(<);
   my $fr = ($_[ 1 ] && $_[ 1 ]->[ 1 ]) || q(>);

   $y =~ s{ \[\% }{${fl}%}gmx; $y =~ s{ \%\] }{%${fr}}gmx;

   return $y;
}

sub exception (;@) {
   return EXCEPTION_CLASS->catch( @_ );
}

sub find_source ($) {
   my $class = shift; my $file = classfile( $class ); my $path;

   for (@INC) {
      $path = abs_path( File::Spec->catfile( $_, $file ) )
         and -f $path and return $path;
   }

   return;
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

sub hex2str (;$) {
   my @a = split m{}mx, shift // q(); my $str = q();

   while (my ($x, $y) = splice @a, 0, 2) { $str .= pack 'C', hex "${x}${y}" }

   return $str;
}

sub home2appldir ($) {
   $_[ 0 ] or return; my $dir = Path::Class::Dir->new( $_[ 0 ] );

   $dir = $dir->parent while ($dir ne $dir->parent and $dir !~ m{ lib \z }mx);

   return $dir->parent;
}

sub is_arrayref (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq q(ARRAY) ? 1 : 0;
}

sub is_coderef (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq q(CODE) ? 1 : 0;
}

sub is_hashref (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq q(HASH) ? 1 : 0;
}

sub is_member (;@) {
   my ($candidate, @rest) = @_; $candidate or return;

   is_arrayref $rest[ 0 ] and @rest = @{ $rest[ 0 ] };

   return (first { $_ eq $candidate } @rest) ? 1 : 0;
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
   return split_on__( File::Basename::basename( $_[ 0 ] || q(), EXTNS ) );
}

sub prefix2class (;$) {
   return join q(::), map { ucfirst } split m{ - }mx, my_prefix( $_[ 0 ] );
}

sub product (;@) {
   return ((fold { $_[ 0 ] * $_[ 1 ] })->( 1 ))->( @_ );
}

sub say (;@) {
   my @rest = @_; openhandle *STDOUT or return; chomp( @rest );

   local ($OFS, $ORS) = $OSNAME eq EVIL ? ("\r\n", "\r\n") : ("\n", "\n");

   return print {*STDOUT} @rest
      or throw( error => 'IO error [_1]', args =>[ $ERRNO ] );
}

sub split_on__ (;$$) {
   return (split m{ _ }mx, $_[ 0 ] || q())[ $_[ 1 ] || 0 ];
}

sub squeeze (;$) {
   (my $y = $_[ 0 ] || q()) =~ s{ \s+ }{ }gmx; return $y;
}

sub strip_leader (;$) {
   (my $y = $_[ 0 ] || q()) =~ s{ \A [^:]+ [:] \s+ }{}msx; return $y;
}

sub sub_name (;$) {
   my $x = $_[ 0 ] || 0;

   return (split m{ :: }mx, ((caller ++$x)[ 3 ]) || q(main))[ -1 ];
}

sub sum (;@) {
   return ((fold { $_[ 0 ] + $_[ 1 ] })->( 0 ))->( @_ );
}

sub throw (;@) {
   EXCEPTION_CLASS->throw( @_ );
}

sub trim (;$) {
   (my $y = $_[ 0 ] || q()) =~ s{ \A \s+ }{}gmx;

   chomp $y; $y =~ s{ \s+ \z }{}gmx; return $y;
}

sub unescape_TT (;$$) {
   my $y  = defined $_[ 0 ] ? $_[ 0 ] : q();
   my $fl = ($_[ 1 ] && $_[ 1 ]->[ 0 ]) || q(<);
   my $fr = ($_[ 1 ] && $_[ 1 ]->[ 1 ]) || q(>);

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
   my ($regex, $string) = @_; my ($untainted) = ($string || q()) =~ $regex;

   (defined $untainted and $untainted eq $string)
      or throw( 'String '.($string || 'undef')." contains possible taint\n" );

   return $untainted;
}

sub zip (@) {
    my $p = @_ / 2; return @_[ map { $_, $_ + $p } 0 .. $p - 1 ];
}

1;

__END__

=pod

=head1 Name

CatalystX::Usul::Functions - Globally accessible functions

=head1 Version

0.6.$Revision$

=head1 Synopsis

   package MyBaseClass;

   use CatalystX::Usul::Functions;

=head1 Description

Provides globally accessible functions

=head1 Subroutines/Methods

=head2 abs_path

   $absolute_untainted_path = abs_path $some_path;

Untaints path. Makes it an absolute path and returns it. Returns undef otherwise

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
L<assert constant|CatalystX::Usul::Constants/ASSERT> can be set via
an inherited class attribute to do something useful with whatever parameters
are passed to it

=head2 assert_directory

   $untained_path = assert_directory $path_to_directory;

Untaints directory path. Makes it an absolute path and returns it if it
exists. Returns undef otherwise

=head2 bsonid

   $bson_id = bsonid;

Generate a new BSON id. Returns a 24 character string of hex digits that
are reasonably unique across hosts and are in ascending order. Use this
to create unique ids for data streams like message queues and file feeds

=head2 bsonid_time

   $seconds_elapsed_since_the_epoch = bsonid_time $bson_id;

Returns the time the BSON id was generated as Unix time

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

=head2 data_dumper

   data_dumper $thing;

Uses L<Data::Printer> to dump C<$thing> in colour to I<stderr>

=head2 distname

   $distname = distname __PACKAGE__;

Takes a class name and returns it with B<::> changed to
B<->, e.g. C<App::Munchies> becomes C<App-Munchies>

=head2 downgrade

   $sv_pv = downgrade $sv_pvgv;

Horrendus Perl bug is promoting PV and PVMG type scalars to PVGV. Serializing
these values with L<Storable> throws a can't store SCALAR items errror. This
functions copys the string value of the input scalar to the output scalar
but resets the output scalar type to PV

=head2 elapsed

   $elapsed_seconds = elapsed;

Returns the number of seconds elapsed since the process started

=head2 env_prefix

   $prefix = env_prefix $class;

Returns upper cased C<app_prefix>. Suitable as prefix for environment
variables

=head2 escape_TT

   $text = escape_TT q([% some_stash_key %]);

The left square bracket causes problems in some contexts. Substitute a
less than symbol instead. Also replaces the right square bracket with
greater than for balance. L<Template::Toolkit> will work with these
sequences too, so unescaping isn't absolutely necessary

=head2 exception

   $e = exception $error;

Expose the C<catch> method in the exception
class L<CatalystX::Usul::Exception>. Returns a new error object

=head2 find_source

   $path = find_source $module_name;

Find absolute path to the source code for the given module

=head2 fold

   *sum = fold { $a + $b } 0;

Classic reduce function with optional base value

=head2 hex2str

   $string = hex2str $pairs_of_hex_digits;

Converts the pairs of hex digits into a string of characters

=head2 home2appldir

   $appldir = home2appldir $home_dir;

Strips the trailing C<lib/my_package> from the supplied directory path

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

   $bool = is_member q(test_value), qw(a_value test_value b_value);

Tests to see if the first parameter is present in the list of
remaining parameters

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

=head2 prefix2class

   $class = prefix2class $PROGRAM_NAME;

Calls L</my_prefix> with the supplied argument, splits the result on dash,
C<ucfirst>s the list and then C<join>s that with I<::>

=head2 product

   $product = product( 1, 2, 3, 4 );

Returns the product of the list of numbers

=head2 say

   say @lines_of_text;

Prints to I<STDOUT> the lines of text passed to it. Lines are C<chomp>ed
and then have newlines appended. Throws on IO errors

=head2 split_on__

   $field = split_on__ $string, $field_no;

Splits string by _ (underscore) and returns the requested field. Defaults
to field zero

=head2 squeeze

   $string = squeeze $string_containing_muliple_spacesd);

Squeezes multiple whitespace down to a single space

=head2 strip_leader

   $stripped = strip_leader q(my_program: Error message);

Strips the leading "program_name: whitespace" from the passed argument

=head2 sub_name

   $sub_name = sub_name $level;

Returns the name of the method that calls it

=head2 sum

   $total = sum 1, 2, 3, 4;

Adds the list of values

=head2 throw

   throw error => q(error_key), args => [ q(error_arg) ];

Expose L<CatalystX::Usul::Exception/throw>. C<CX::Usul::Functions> has a
class attribute I<Exception_Class> which can be set via a call to
C<set_inherited>

=head2 trim

   $trimmed_string = trim $string_with_leading_and trailing_whitespace;

Remove leading and trailing whitespace including trailing newlines

=head2 unescape_TT

   $text = unescape_TT q(<% some_stash_key %>);

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

=head2 zip

   %hash = zip @list_of_keys @list_of_values;

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

=item L<List::Util>

=item L<Path::Class::Dir>

=back

=head1 Incompatibilities

The L</home2appldir> method is dependent on the installation path
containing a B<lib>

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
