# @(#)$Id$

package Class::Usul::Build;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use parent qw(Module::Build);

use Class::Usul::Build::InstallActions;
use Class::Usul::Build::Questions;
use Class::Usul::Build::VCS;
use Class::Usul::Constants;
use Class::Usul::Programs;
use TryCatch;
use File::Spec;
use MRO::Compat;
use Perl::Version;
use Module::CoreList;
use Pod::Eventual::Simple;
use English    qw(-no_match_vars);
use File::Copy qw(copy);
use File::Find qw(find);
use File::Path qw(make_path);

if ($ENV{AUTOMATED_TESTING}) {
   # Some CPAN testers set these. Breaks dependencies
   $ENV{PERL_TEST_CRITIC} = FALSE; $ENV{PERL_TEST_POD} = FALSE;
   $ENV{TEST_CRITIC     } = FALSE; $ENV{TEST_POD     } = FALSE;
}

my $ARRAYS        = [ qw(copy_files create_dirs create_files credentials
                         link_files run_cmds) ];
my $CFG_FILE      = q(build.xml);
my $CHANGE_ARGS   = [ q({{ $NEXT }}), q(%-9s %s), q(%Y-%m-%d %T %Z) ];
my $CHANGES_FILE  = q(Changes);
my $LICENSE_FILE  = q(LICENSE);
my $MANIFEST_FILE = q(MANIFEST);
my %META_KEYS     =
   ( perl         => 'Perl_5',
     apache       => [ map { "Apache_$_" } qw(1_1 2_0) ],
     artistic     => 'Artistic_1_0',
     artistic_2   => 'Artistic_2_0',
     lgpl         => [ map { "LGPL_$_" } qw(2_1 3_0) ],
     bsd          => 'BSD',
     gpl          => [ map { "GPL_$_" } qw(1 2 3) ],
     mit          => 'MIT',
     mozilla      => [ map { "Mozilla_$_" } qw(1_0 1_1) ], );
my $MIN_PERL_VER  = q(5.008);

# Around these M::B actions

sub ACTION_build {
   my $self = shift; my $cfg = $self->read_config_file;

   $cfg->{built} or $self->ask_questions( $cfg );

   return $self->next::method();
}

sub ACTION_distmeta {
   my $self = shift;

   $self->update_changelog( $self->_dist_version );
   $self->write_license_file;

   return $self->next::method();
}

sub ACTION_install {
   my $self = shift; my $cfg = $self->read_config_file;

   $self->cli->info( 'Base path '.$self->set_base_path( $cfg ) );
   $self->next::method();

   my $install = $self->install_actions_class->new( builder => $self );

   # Call each of the defined actions
   $install->$_( $cfg ) for (grep { $cfg->{ $_ } } @{ $install->actions });

   return $cfg;
}

# New M::B actions

sub ACTION_change_version {
   my $self = shift;

   $self->depends_on( q(manifest) );
   $self->depends_on( q(release)  );
   $self->change_version;
   return;
}

sub ACTION_installdeps {
   # Install all the dependent modules
   my $self = shift;

   $self->cli->ensure_class_loaded( q(CPAN) );

   for my $depend (grep { $_ ne q(perl) } keys %{ $self->requires }) {
      CPAN::Shell->install( $depend );
   }

   return;
}

sub ACTION_prereq_update {
   my $self = shift; my $field = $self->args->{ARGV}->[ 0 ] || q(requires);

   $self->prereq_update( $field );
   return;
}

sub ACTION_release {
   my $self = shift;

   $self->depends_on( q(distmeta) );
   $self->commit_release( 'release '.$self->_dist_version );
   return;
}

sub ACTION_upload {
   # Upload the distribution to CPAN
   my $self = shift;

   $self->depends_on( q(release) );
   $self->depends_on( q(dist) );
   $self->cpan_upload;
   return;
}

# Public object methods

sub ask_questions {
   my ($self, $cfg) = @_;

   my $cli  = $self->cli;
   my $quiz = $self->question_class->new( builder => $self );

   # Update the config by looping through the questions
   for my $attr (@{ $quiz->config_attributes }) {
      my $question = q(q_).$attr;

      $cfg->{ $attr } = $quiz->$question( $cfg );
   }

   # Save the updated config for the install action to use
   $self->write_config_file( $cfg );
   $cfg->{ask} and $cli->anykey;
   return;
}

sub change_version {
   my $self = shift;
   my $cli  = $self->cli;
   my $comp = $cli->get_line( 'Enter major/minor 0 or 1',  1, TRUE, 0 );
   my $bump = $cli->get_line( 'Enter increment/decrement', 0, TRUE, 0 )
           or return;
   my $ver  = $self->_dist_version or return;
   my $from = __tag_from_version( $ver );

   $ver->component( $comp, $ver->component( $comp ) + $bump );
   $comp == 0 and $ver->component( 1, 0 );
   $self->_update_version( $from, __tag_from_version( $ver ) );
   $self->_create_tag_release( $from );
   $self->update_changelog( $ver = $self->_dist_version );
   $self->commit_release( 'first '.__tag_from_version( $ver ) );
   $self->_rebuild_build;
   return;
}

sub class_path {
   return File::Spec->catfile( q(lib), split m{ :: }mx, $_[1].q(.pm) );
}

sub cli {
   # Self initialising accessor for the command line interface object
   my $self = shift; my $key = q(_command_line_interface);

   $self->{ $key }
      or $self->{ $key } = Class::Usul::Programs->new
            ( appclass => $self->module_name, debug => FALSE );

   return $self->{ $key };
}

sub commit_release {
   my ($self, $msg) = @_;

   my $vcs = $self->_vcs or return; my $cli = $self->cli;

   $vcs->commit( ucfirst $msg ) and $cli->say( "Committed $msg" );
   $vcs->error and $cli->say( @{ $vcs->error } );
   return;
}

sub cpan_upload {
   my $self = shift;
   my $cli  = $self->cli;
   my $args = $self->_read_pauserc;

   $args->{subdir} = lc $self->dist_name;
   exists $args->{dry_run} or $args->{dry_run}
      = $cli->yorn( 'Really upload to CPAN', FALSE, TRUE, 0 );
   $cli->ensure_class_loaded( q(CPAN::Uploader) );
   CPAN::Uploader->upload_file( $self->dist_dir.q(.tar.gz), $args );
   return;
}

sub distname {
   my $distname = $_[1]; $distname =~ s{ :: }{-}gmx; return $distname;
}

sub install_actions_class {
   return __PACKAGE__.q(::InstallActions);
}

sub post_install {
   my ($self, $cfg) = @_; my $cli = $self->cli;

   my $bind = $self->install_destination( q(bin) );

   $cli->info( 'The following commands may take a *long* time to complete' );

   for my $cmd (@{ $cfg->{run_cmds} || [] }) {
      my $prog = (split SPC, $cmd)[0];

      not $cli->io( $prog )->is_absolute and $cmd = $cli->catdir( $bind, $cmd);
      $cmd =~ s{ \[% \s+ (\w+) \s+ %\] }{$cfg->{ $1 }}gmx;

      if ($cfg->{run_cmd}) {
         $cli->info( "Running $cmd" );
         $cli->info( $cli->run_cmd( $cmd )->out );
      }
      else { $cli->info( "Would run $cmd" ) }
   }

   return;
}

sub prereq_update {
   my ($self, $field) = @_;

   my $filter   = q(_filter_).$field.q(_paths);
   my $prereqs  = $self->prereq_data->{ $field };
   my $paths    = $self->$filter( $self->_source_paths );
   my $used     = $self->_filter_dependents( $self->_dependencies( $paths ) );
   my $compares = $self->_compare_prereqs_with_used( $field, $prereqs, $used );

   $self->_prereq_comparison_report( $compares );
   # TODO: Update the versions in prereqs
   return;
}

sub process_files {
   # Find and copy files and directories from source tree to destination tree
   my ($self, $src, $dest) = @_; $src or return; $dest ||= q(blib);

   if    (-f $src) { $self->_copy_file( $src, $dest ) }
   elsif (-d $src) {
      my $prefix = $self->base_dir;

      find( { no_chdir => TRUE, wanted => sub {
         (my $path = $File::Find::name) =~ s{ \A $prefix }{}mx;
         return $self->_copy_file( $path, $dest );
      }, }, $src );
   }

   return;
}

sub public_repository {
   # Accessor for the public VCS repository information
   my $class = shift; my $repo = $class->repository or return;

   return $repo !~ m{ \A file: }mx ? $repo : undef;
}

sub question_class {
   return __PACKAGE__.q(::Questions);
}

sub read_config_file {
   my $self = shift;
   my $cli  = $self->cli;
   my $path = $cli->catfile( $self->base_dir, $CFG_FILE );
   my $cfg  = {};

   -f $path or return $cfg;

   try        { $cfg = $cli->data_load( arrays => $ARRAYS, path => $path ) }
   catch ($e) { $cli->fatal( $e ) }

   return $cfg;
}

sub replace {
   # Edit a file and replace one string with another
   my ($self, $this, $that, $path) = @_; my $cli = $self->cli;

   -s $path or $cli->fatal( "File $path not found or zero length" );

   my $wtr = $cli->io( $path )->atomic;

   for ($cli->io( $path )->getlines) {
      s{ $this }{$that}gmx; $wtr->print( $_ );
   }

   $wtr->close;
   return;
}

sub repository {
   my $vcs = shift->_vcs or return; return $vcs->repository;
}

sub resources {
   my ($class, $license, $tracker, $home_page, $distname) = @_;

   my $resources  = { license => $license, bugtracker => $tracker.$distname };
   my $repository = $class->public_repository;

   $home_page  and $resources->{homepage  } = $home_page;
   $repository and $resources->{repository} = $repository;

   return $resources;
}

sub set_base_path {
   my ($self, $cfg) = @_;

   my $cli = $self->cli; my $prefix = $cfg->{path_prefix};

   -d $prefix or make_path( $prefix, { mode => oct q(02750) } );
   -d $prefix or $cli->fatal( "Path $prefix cannot create" );

   my $base = $cli->catdir( $prefix,
                            $cli->class2appdir( $self->module_name ),
                            q(v).$cfg->{ver}.q(p).$cfg->{phase} );

   if ($cfg->{style} and $cfg->{style} eq q(normal)) {
      $self->install_base( $base );
      $self->install_path( bin => $cli->catdir( $base, q(bin) ) );
      $self->install_path( lib => $cli->catdir( $base, q(lib) ) );
      $self->install_path( var => $cli->catdir( $base, q(var) ) );
   }
   else { $self->install_path( var => $base ) }

   return $cfg->{base} = $base;
}

sub skip_pattern {
   # Accessor/mutator for the regular expression of paths not to process
   my ($self, $re) = @_;

   defined $re and $self->{_skip_pattern} = $re;

   return $self->{_skip_pattern};
}

sub update_changelog {
   my ($self, $ver) = @_;
   my ($tok, $line_format, $time_format) = @{ $CHANGE_ARGS };
   my $file = $CHANGES_FILE;
   my $cli  = $self->cli;
   my $io   = $cli->io( $file );
   my $time = $cli->time2str( $time_format, time );
   my $line = sprintf $line_format, $ver->normal, $time;
   my $tag  = q(v).__tag_from_version( $ver );
   my $text = $io->all;

   if (   $text =~ m{ ^   \Q$tag\E }mx)    {
          $text =~ s{ ^ ( \Q$tag\E .* ) $ }{$line}mx   }
   else { $text =~ s{   ( \Q$tok\E    )   }{$1\n\n$line}mx }

   $cli->say( "Updating $file" );
   $io->close->print( $text );
   return;
}

sub write_config_file {
   my ($self, $cfg) = @_;

   my $cli  = $self->cli;
   my $path = $cli->catfile( $self->base_dir, $CFG_FILE );

   defined $path or $cli->fatal( 'Config path undefined' );
   defined $cfg  or $cli->fatal( 'Config data undefined' );

   try        { $cli->data_dump( data => $cfg, path => $path ) }
   catch ($e) { $cli->fatal( $e ) }

   return $cfg;
}

sub write_license_file {
   my $self    = shift;
   my $license = $META_KEYS{ $self->license } or return;
      $license = ref $license ? $license->[ -1 ] : $license;
   my $class   = q(Software::License::).$license;
   my $cli     = $self->cli;

   $cli->ensure_class_loaded( $class );
   $cli->say( "Creating $LICENSE_FILE" );
   $license = $class->new( { holder => $cli->get_meta->author->[ 0 ] } );
   $cli->io( $LICENSE_FILE )->print( $license->fulltext );
   return;
}

# Private methods

sub _compare_prereqs_with_used {
   my ($self, $field, $prereqs, $used) = @_;

   my $result     = {};
   my $add_key    = "Would add these to the $field in Build.PL";
   my $remove_key = "Would remove these from the $field in Build.PL";
   my $update_key = "Would update these in the $field in Build.PL";

   for (grep { defined $used->{ $_ } } keys %{ $used }) {
      if (exists $prereqs->{ $_ }) {
         my $oldver = version->new( $prereqs->{ $_ } );
         my $newver = version->new( $used->{ $_ }    );

         if ($newver != $oldver) {
            $result->{ $update_key }->{ $_ }
               = $prereqs->{ $_ }.q( => ).$used->{ $_ };
         }
      }
      else { $result->{ $add_key }->{ $_ } = $used->{ $_ } }
   }

   for (keys %{ $prereqs }) {
      exists $used->{ $_ }
         or $result->{ $remove_key }->{ $_ } = $prereqs->{ $_ };
   }

   return $result;
}

sub _consolidate {
   my ($self, $used) = @_; my (%dists, %result);

   $self->cli->ensure_class_loaded( q(CPAN) );

   for my $used_key (keys %{ $used }) {
      my ($curr_dist, $module, $used_dist); my $try_module = $used_key;

      while ($curr_dist = __dist_from_module( $try_module )
             and (not $used_dist
                  or  $curr_dist->base_id eq $used_dist->base_id)) {
         $module = $try_module;
         $used_dist or $used_dist = $curr_dist;
         $try_module =~ m{ :: }mx or last;
         $try_module =~ s{ :: [^:]+ \z }{}mx;
      }

      unless ($module) {
         $result{ $used_key } = $used->{ $used_key }; next;
      }

      exists $dists{ $module } and next;
      $dists{ $module } = $self->_version_from_module( $module );
   }

   $result{ $_ } = $dists{ $_ } for (keys %dists);

   return \%result;
}

sub _copy_file {
   my ($self, $src, $dest) = @_;

   my $cli = $self->cli; my $pattern = $self->skip_pattern;

   return unless ($src and -f $src and (not $pattern or $src !~ $pattern));

   # Rebase the directory path
   my $dir = $cli->catdir( $dest, $cli->dirname( $src ) );

   # Ensure target directory exists
   -d $dir or make_path( $dir, { mode => oct q(02750) } );

   copy( $src, $dir );
   return;
}

sub _create_tag_release {
   my ($self, $tag) = @_;

   my $vcs  = $self->_vcs or return; my $cli = $self->cli;

   $cli->say( "Creating tagged release v$tag" );
   $vcs->tag( $tag );
   $vcs->error and $cli->say( @{ $vcs->error } );
   return;
}

sub _dependencies {
   my ($self, $paths) = @_; my $used = {};

   for my $path (@{ $paths }) {
      my $lines = __read_non_pod_lines( $path );

      for my $line (split m{ \n }mx, $lines) {
         my $modules = __parse_depends( $line ); $modules->[ 0 ] or next;

         for (@{ $modules }) {
            __looks_like_version( $_ ) and $used->{perl} = $_ and next;

            not exists $used->{ $_ }
               and $used->{ $_ } = $self->_version_from_module( $_ );
         }
      }
   }

   return $used;
}

sub _dist_version {
   my $self = shift;
   my $file = $self->dist_version_from;
   my $info = Module::Build::ModuleInfo->new_from_file( $file );

   return Perl::Version->new( $info->version );
}

sub _draw_line {
    my ($self, $count) = @_; return $self->cli->say( q(-) x ($count || 60) );
}

sub _filter_dependents {
   my ($self, $used) = @_;
   my $perl_version  = $used->{ perl } || $MIN_PERL_VER;
   my $core_modules  = $Module::CoreList::version{ $perl_version };
   my $provides      = $self->cli->get_meta->provides;

   return $self->_consolidate( { map   { $_ => $used->{ $_ }              }
                                 grep  { not exists $core_modules->{ $_ } }
                                 grep  { not exists $provides->{ $_ }     }
                                 keys %{ $used } } );
}

sub _filter_build_requires_paths {
   return [ grep { m{ \.t \z }mx } @{ $_[ 1 ] } ];
}

sub _filter_configure_requires_paths {
   return [ grep { $_ eq q(Build.PL) } @{ $_[ 1 ] } ];
}

sub _filter_requires_paths {
   return [ grep { not m{ \.t \z }mx and $_ ne q(Build.PL) } @{ $_[ 1 ] } ];
}

sub _prereq_comparison_report {
   my ($self, $diffs) = @_; my $cli = $self->cli; $self->_draw_line;

   for my $table (sort keys %{ $diffs }) {
      $cli->say( $table ); $self->_draw_line;

      for (sort keys %{ $diffs->{ $table } }) {
         $cli->say( "'$_' => '".$diffs->{ $table }->{ $_ }."'," );
      }

      $self->_draw_line;
   }

   return;
}

sub _read_pauserc {
   my $self    = shift;
   my $cli     = $self->cli;
   my $pauserc = $cli->catfile( $ENV{HOME} || File::Spec->curdir, q(.pause) );
   my $args    = {};

   for ($cli->io( $pauserc )->chomp->getlines) {
      next unless ($_ and $_ !~ m{ \A \s* \# }mx);
      my ($k, $v) = m{ \A \s* (\w+) \s+ (.+) \z }mx;
      exists $args->{ $k } and die "Multiple enties for $k";
      $args->{ $k } = $v;
   }

   return $args;
}

sub _rebuild_build {
   my $self = shift; my $cmd = [ $EXECUTABLE_NAME, q(Build.PL) ];

   $self->cli->run_cmd( $cmd, { err => q(out) } );
   return;
}

sub _source_paths {
   my $self = shift; my $cli = $self->cli;

   return [ grep { __is_perl_script( $cli, $_ ) }
            map  { s{ \s+ }{ }gmx; (split SPC, $_)[0] }
            $cli->io( $MANIFEST_FILE )->chomp->getlines ];
}

sub _update_version {
   my ($self, $from, $to) = @_;

   my $cli   =  $self->cli;
   my $prog  =  $EXECUTABLE_NAME;
   my $cmd   =  $self->notes->{version_pattern} or return;
      $cmd   =~ s{ \$\{from\} }{$from}gmx;
      $cmd   =~ s{ \$\{to\} }{$to}gmx;
      $cmd   =  [ q(xargs), q(-i), $prog, q(-pi), q(-e), "'".$cmd."'", q({}) ];
   my $paths =  [ map { "$_\n" } @{ $self->_source_paths } ];

   $cli->popen( $cmd, { err => q(out), in => $paths } );
   return;
}

sub _vcs {
   my $self = shift; my $is_ref = ref $self;

   $is_ref and $self->{_vcs} and return $self->{_vcs};

   my $class  = __PACKAGE__.q(::VCS);
   my $cli    = $is_ref ? $self->cli              : undef;
   my $dir    = $cli    ? $cli->config->{appldir} : File::Spec->curdir;
   my $config = $cli    ? $cli->config            : {};
   my $vcs    = $class->new( project_dir => $dir, config => $config );

   $is_ref and $self->{_vcs} = $vcs;

   return $vcs;
}

sub _version_from_module {
   my ($self, $module) = @_; my $version;

   eval "no warnings; require $module; \$version = $module->VERSION;";

   return $self->cli->catch || ! $version ? undef : $version;
}

# Private subroutines

sub __dist_from_module {
   my $module = CPAN::Shell->expand( q(Module), $_[ 0 ] );

   return $module ? $module->distribution : undef;
}

sub __is_perl_script {
   my ($cli, $path) = @_;

   $path =~ m{ (?: \.pm | \.t | \.pl ) \z }imx and return TRUE;

   my $line = $cli->io( $path )->getline;

   return $line =~ m{ \A \#! (?: .* ) perl (?: \s | \z ) }mx ? TRUE : FALSE;
}

sub __looks_like_version {
    my $ver = shift;

    return defined $ver && $ver =~ m{ \A v? \d+ (?: \.[\d_]+ )? \z }mx;
}

sub __parse_depends {
   my $line = shift; my $modules = [];

   for my $stmt (grep   { length }
                 map    { s{ \A \s+ }{}mx; s{ \s+ \z }{}mx; $_ }
                 split m{ ; }mx, $line) {
      if ($stmt =~ m{ \A (?: use | require ) \s+ }mx) {
         my (undef, $module, $rest) = split m{ \s+ }mx, $stmt, 3;

         # Skip common pragma and things that don't look like module names
         $module =~ m{ \A (?: lib | strict | warnings ) \z }mx and next;
         $module =~ m{ [^\.:\w] }mx and next;

         push @{ $modules }, $module eq q(base) || $module eq q(parent)
                          ? ($module, __parse_list( $rest )) : $module;
      }
      elsif ($stmt =~ m{ \A (?: with | extends ) \s+ (.+) }mx) {
         push @{ $modules }, __parse_list( $1 );
      }
   }

   return $modules;
}

sub __parse_list {
   my $string = shift;

   $string =~ s{ \A q w* [\(/] \s* }{}mx;
   $string =~ s{ \s* [\)/] \z }{}mx;
   $string =~ s{ [\'\"] }{}gmx;
   $string =~ s{ , }{ }gmx;

   return grep { length && !m{ [^\.:\w] }mx } split m{ \s+ }mx, $string;
}

sub __read_non_pod_lines {
   my $path = shift; my $p = Pod::Eventual::Simple->read_file( $path );

   return join "\n", map  { $_->{content} }
                     grep { $_->{type} eq q(nonpod) } @{ $p };
}

sub __tag_from_version {
   my $ver = shift; return $ver->component( 0 ).q(.).$ver->component( 1 );
}

1;

__END__

=pod

=head1 Name

Class::Usul::Build - M::B utility methods

=head1 Version

This document describes Class::Usul::Build version 0.1.$Revision$

=head1 Synopsis

   use Class::Usul::Build;
   use MRO::Compat;

   my $builder = q(Class::Usul::Build);
   my $class   = $builder->subclass( class => 'Bob', code  => <<'EOB' );

   sub ACTION_instal { # Spelling mistake intentional
      my $self = shift;

      $self->next::method();

      # Your application specific post installation code goes here

      return;
   }
   EOB

=head1 Description

Subclasses L<Module::Build>. Ask questions during the build phase and stores
the answers for use during the install phase. The answers to the questions
determine where the application will be installed and which additional
actions will take place. Should be generic enough for any web application

=head1 ACTIONS

=head2 ACTION_build

=head2 build

When called by it's subclass this method prompts the user for
information about how this installation is to be performed. User
responses are saved to the F<build.xml> file. The
L<Class::Usul::Build::Questions/config_attributes> returns the list of
questions to ask

=head2 ACTION_change_version

=head2 change_version

Changes the C<$VERSION> strings in all of the projects files

=head2 ACTION_distmeta

=head2 distmeta

Updates license file and changelog

=head2 ACTION_extract_use

=head2 extract_use

Dumps out a list of module names and version numbers of all the
modules used in the project. Useful for maintaining the I<REQUIRES>
hash in the F<Build.PL> file

=head2 ACTION_install

=head2 install

When called from it's subclass this method performs the sequence of
actions required to install the application. Configuration options are
read from the file F<build.xml>. The L</actions> method returns the
list of steps required to install the application

=head2 ACTION_installdeps

=head2 installdeps

Iterates over the I<requires> attributes calling L<CPAN> each time to
install the dependent module

=head2 ACTION_prereq_update

=head2 prereq_update

=head2 ACTION_release

=head2 release

Commits the current working copy as the next release

=head2 ACTION_upload

=head2 upload

Upload distribution to CPAN

=head1 Subroutines/Methods

=head2 actions

   $current_list_of_actions = $builder->actions( $new_list_of_actions );

This accessor/mutator method defaults to the list defined in the C<$ACTIONS>
package variable

=head2 ask_questions

   $builder->ask_questions( $config );

Called by the L</ACTION_build> method

=head2 class_path

=head2 cli

   $cli = $builder->cli;

Returns an instance of L<Class::Usul::Programs>, the command line
interface object

=head2 commit_release

   $builder->commit_release( 'Release message for VCS log' );

Commits the release to the VCS

=head2 cpan_upload

   $builder->cpan_upload;

Called by L</ACTION_upload>. Uses L<CPAN::Uploader> (which it loads on
demand) to do the lifting. Reads from the users F<.pause> in their
C<$ENV{HOME}> directory


=head2 distname

=head2 install_actions_class

=head2 post_install

   $builder->post_install( $config );

Executes the custom post installation commands

=head2 process_files

   $builder->process_files( $source, $destination );

Handles the processing of files other than library modules and
programs.  Uses the I<Bob::skip_pattern> defined in the subclass to
select only those files that should be processed.  Copies files from
source to destination, creating the destination directories as
required. Source can be a single file or a directory. The destination
is optional and defaults to B<blib>

=head2 public_repository

Return the URI of the SVN repository for this project. Return undef
if we are not using svn or the repository is a local file path

=head2 question_class

=head2 read_config_file

   $config = $builder->read_config_file( $path );

Reads the configuration information from F<$path> using L<XML::Simple>.
The package variable C<$ARRAYS> is passed to L<XML::Simple> as the
I<ForceArray> attribute. Called by L</ACTION_build> and L<ACTION_install>

=head2 replace

   $builder->replace( $this, $that, $path );

Substitutes C<$this> string for C<$that> string in the file F<$path>

=head2 repository

Returns the URI of the VCS repository for this project

=head2 resources

=head2 set_base_path

   $base = $builder->set_base_path( $config );

Uses the C<< $config->{style} >> attribute to set the L<Module::Build>
I<install_base> attribute to the base directory for this installation.
Returns that path. Also sets; F<bin>, F<lib>, and F<var> directory paths
as appropriate. Called from L<ACTION_install>

=head2 skip_pattern

   $regexp = $builder->skip_pattern( $new_regexp );

Accessor/mutator method. Used by L</_copy_file> to skip processing files
that match this pattern. Set to false to not have a skip list

=head2 update_changelog

Update the version number and date/time stamp in the F<Changes> file

=head2 write_config_file

   $config = $builder->write_config_file( $path, $config );

Writes the C<$config> hash to the F<$path> file for later use by
the install action. Called from L<ACTION_build>

=head2 write_license_file

Instantiates an instance of L<Software::License>, fills in the copyright
holder information and writes a F<LICENSE> file

=head1 Private Methods

=head2 _copy_file

   $builder->_copy_file( $source, $destination );

Called by L</process_files>. Copies the C<$source> file to the
C<$destination> directory

=head1 Diagnostics

None

=head1 Configuration and Environment

Edits and stores config information in the file F<build.xml>

=head1 Dependencies

=over 3

=item L<Class::Usul::Programs>

=item L<Module::Build>

=item L<SVN::Class>

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
