# @(#)$Id$
# Bob-Version: 1.7

use Pod::Select;

sub ACTION_distmeta {
   my $self = shift;

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

