# @(#)$Ident: L10N.pm 2013-11-07 14:07 pjf ;

package Class::Usul::L10N;

use 5.010001;
use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.32.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Null;
use Class::Usul::Constants;
use Class::Usul::Functions  qw( assert is_arrayref merge_attributes );
use Class::Usul::Types      qw( ArrayRef Bool HashRef LogType
                                SimpleStr Str Undef );
use File::DataClass::Types  qw( Directory Lock Path );
use File::Gettext::Constants;
use File::Gettext;
use File::Spec;
use Moo;
use Try::Tiny;

# Public attributes
has 'debug'           => is => 'rw',   isa => Bool, default => FALSE;

has 'domain_names'    => is => 'ro',   isa => ArrayRef[Str],
   default            => sub { [ 'messages' ] };

has 'l10n_attributes' => is => 'ro',   isa => HashRef, default => sub { {} };

has 'localedir'       => is => 'ro',   isa => Path | Undef,
   coerce             => Path->coercion;

has 'lock'            => is => 'ro',   isa => Lock,
   default            => sub { Class::Null->new };

has 'log'             => is => 'ro',   isa => LogType,
   default            => sub { Class::Null->new };

has 'tempdir'         => is => 'ro',   isa => Directory,
   coerce             => Directory->coercion, default => File::Spec->tmpdir;

# Private attributes
has '_source_name'    => is => 'lazy', isa => SimpleStr, builder => sub {
   $_[ 0 ]->l10n_attributes->{source_name} || 'po' },
   init_arg           => undef, reader => 'source_name';

has '_use_country'    => is => 'lazy', isa => Bool, builder => sub {
   $_[ 0 ]->l10n_attributes->{use_country} || FALSE },
   init_arg           => undef, reader => 'use_country';

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $class, @args) = @_; my $attr = $orig->( $class, @args );

   my $builder = delete $attr->{builder} or return $attr;
   my $config  = $builder->can( 'config' ) ? $builder->config : {};

   merge_attributes $attr, $builder, {}, [ qw( debug lock log ) ];
   merge_attributes $attr, $config,  {},
      [ qw( l10n_attributes localedir tempdir ) ];

   return $attr;
};

# Public methods
sub get_po_header {
   my ($self, $args) = @_;

   my $domain = $self->_load_domains( $args || {} ) or return {};
   my $header = $domain->{po_header} or return {};

   return $header->{msgstr} || {};
}

sub invalidate_cache {
   $_[ 0 ]->_invalidate_cache; return;
}

sub localize {
   my ($self, $key, $args) = @_;

   $key or return; $key = "${key}"; chomp $key; $args //= {};

   # Lookup the message using the supplied key from the po file
   my $text = $self->_gettext( $key, $args );

   if (is_arrayref $args->{params}) {
      0 > index $text, LOCALIZE and return $text;

      # Expand positional parameters of the form [_<n>]
      my @args = map { $args->{quote_bind_values} ? "'${_}'" : $_ }
                 map { (length) ? $_  : '[]'  }
                 map {            $_ // '[?]' } @{ $args->{params} },
                 map {                  '[?]' } 0 .. 9;

      $text =~ s{ \[ _ (\d+) \] }{$args[ $1 - 1 ]}gmx; return $text;
   }

   0 > index $text, LBRACE and return $text;

   # Expand named parameters of the form {param_name}
   my %args = %{ $args }; my $re = join '|', map { quotemeta $_ } keys %args;

   $text =~ s{ \{($re)\} }{ defined $args{ $1 } ? $args{ $1 } : "{$1}" }egmx;
   return $text;
}

# Private methods
sub _extract_lang_from {
   my ($self, $locale) = @_; state $cache ||= {};

   defined $cache->{ $locale } and return $cache->{ $locale };

   my $sep  = $self->use_country ? '.' : '_';
   my $lang = (split m{ \Q$sep\E }msx, $locale.$sep )[ 0 ];

   return $cache->{ $locale } = $lang;
}

sub _gettext {
   my ($self, $key, $args) = @_;

   my $count   = $args->{count} || 1;
   my $default = $args->{no_default} ? NUL : $key;
   my $domain  = $self->_load_domains( $args )
      or return ($default, $args->{plural_key})[ $count > 1 ] || $default;
   # Select either singular or plural translation
   my ($nplurals, $plural) = (1, 0);

   if ($count > 1) { # Some languages have more than one plural form
      ($nplurals, $plural) = $domain->{plural_func}->( $count );
      defined   $nplurals  or $nplurals = 0;
      defined    $plural   or  $plural  = 0;
      $plural > $nplurals and  $plural  = $nplurals;
   }

   my $id   = defined $args->{context}
            ? $args->{context}.CONTEXT_SEP.$key : $key;
   my $msgs = $domain->{ $self->source_name } || {};
   my $msg  = $msgs->{ $id } || {};

   return @{ $msg->{msgstr} || [] }[ $plural ] || $default;
}

{  my $cache = {};

   sub _invalidate_cache {
      $cache = {};
   }

   sub _load_domains {
      my ($self, $args) = @_; my $charset;

      assert $self, sub { $args->{locale} }, 'No locale id';

      my $locale = $args->{locale} or return;
      my $lang   = $self->_extract_lang_from( $locale );
      my $names  = $args->{domain_names} || $self->domain_names;
      my @names  = grep { defined and length } @{ $names };
      my $key    = $lang.SEP.(join '+', @names );

      defined $cache->{ $key } and return $cache->{ $key };

      my $attrs  = { %{ $self->l10n_attributes }, builder => $self,
                     source_name => $self->source_name, };

      defined $self->localedir and $attrs->{localedir} = $self->localedir;

      $locale    =~ m{ \A (?: [a-z][a-z] )
                          (?: (?:_[A-Z][A-Z] )? \. ( [-_A-Za-z0-9]+ )? )?
                          (?: \@[-_A-Za-z0-9=;]+ )? \z }msx and $charset = $1;
      $charset and $attrs->{charset} = $charset;

      my $domain = try   { File::Gettext->new( $attrs )->load( $lang, @names ) }
                   catch { $self->log->error( $_ ); return };

      return $domain ? $cache->{ $key } = $domain : undef;
   }
}

1;

__END__

=pod

=head1 Name

Class::Usul::L10N - Localize text strings

=head1 Version

This documents version v0.32.$Rev: 1 $

=head1 Synopsis

   use Class::Usul::L10N;

   my $l10n = Class::Usul::L10N->new( {
      localedir    => 'path_to_message_catalogs',
      log          => Log::Handler->new, } );

   $local_text = $l10n->localize( 'message_to_localize', {
      domain_names => [ 'message_file', 'another_message_file' ],
      locale       => 'de_DE',
      params       => { name => 'value', }, } );

=head1 Description

Localize text strings by looking them up in a GNU Gettext PO message catalog

=head1 Configuration and Environment

A POSIX locale id has the form

   <language>_<country>.<charset>@<key>=<value>;...

If the C<use_country> attribute is set to true in the constructor call
then the language and country are used from C<locale>. By default
C<use_country> is false and only the language from the C<locale>
attribute is used

Defines the following attributes;

=over 3

=item C<domain_names>

Names of the mo/po files to search for

=item C<l10n_attributes>

Hash ref passed to the L<File::Gettext> constructor

=over 3

=item C<source_name>

Either C<po> for Portable Object (the default) or C<mo> for the Machine Object

=item C<use_country>

See above

=back

=item C<localedir>

Base directory to search for mo/po files

=item C<lock>

Optional L<IPC::SRLock> object passed to L<File::Gettext>

=item C<log>

Optional logging object

=item C<tempdir>

Directory to use for temporary files

=back

=head1 Subroutines/Methods

=head2 BUILDARGS

Monkey with the constructors signature

=head2 BUILD

Finish initializing the object

=head2 get_po_header

   $po_header_hash_ref = $l10n->get_po_header( { locale => 'de' } );

Returns a hash ref containing the keys and values of the PO header record

=head2 invalidate_cache

   $l10n->invalidate_cache;

Causes a reload of the domain files the next time a message is localized

=head2 localize

   $local_text = $l10n->localize( $key, $args );

Localizes the message. The message catalog is loaded from a GNU
Gettext portable object file. Returns the C<$key> if the message is
not in the catalog (and C<< $args->{no_default} >> is not
true). Language is selected by the C<< $args->{locale} >>
attribute. Expands positional parameters of the form C<< [_<n>] >> if
C<< $args->{params} >> is an array ref of values to
substitute. Otherwise expands named attributes of the form C<<
{attr_name} >> using the C<$args> hash for substitution values. If C<<
$args->{quote_bind_values} >> is true the placeholder values are
displayed wrapped in quotes, The attribute C<< $args->{count} >> is
passed to the portable object files plural function which is used to
select either the singular or plural form of the translation. If C<<
$args->{context} >> is supplied it is prepended to the C<$key> before
the lookup in the catalog takes place

=head1 Diagnostics

Asserts that the I<locale> attribute is set

=head1 Dependencies

=over 3

=item L<Class::Usul::Constants>

=item L<Class::Usul::Functions>

=item L<File::DataClass::Types>

=item L<File::Gettext>

=item L<File::Gettext::Constants>

=item L<Moo>

=item L<Try::Tiny>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 Acknowledgements

Larry Wall - For the Perl programming language

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
