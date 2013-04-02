# @(#)Ident: SubClass.pm 2013-04-02 14:37 pjf ;
# Bob-Version: 1.9

use Pod::Select;

sub ACTION_distmeta {
   my $self = shift;

   $self->notes->{create_readme_md} and $self->_create_readme_md();

   $self->notes->{create_readme_pod} and podselect( {
      -output => q(README.pod) }, $self->dist_version_from );

   return $self->SUPER::ACTION_distmeta;
}

sub create_build_script {
   my $self = shift; $self->SUPER::create_build_script;

   lc $^O eq 'mswin32' or return;
   -f 'Build' or warn "NTFS: Read immediately after write bug detected\n";
   sleep 10; # Allow NTFS to catch up
   -f 'Build' and return;
   warn "NTFS: Build file not found... bodging\n";
   open my $fh, '>', 'Build'; print {$fh} "exit 0;\n"; close $fh; sleep 10;
   return;
}

# Private methods

sub _create_readme_md {
   print "Creating README.md using Pod::Markdown\n"; require Pod::Markdown;

   my $self   = shift;
   my $parser = Pod::Markdown->new;
   my $path   = $self->dist_version_from;

   open my $in,  '<', $path       or die "Path ${path} cannot open: ${!}";
   $parser->parse_from_filehandle( $in ); close $in;
   open my $out, '>', 'README.md' or die "File README.md cannot open: ${!}";
   print {$out} $parser->as_markdown; close $out;
   return;
}
