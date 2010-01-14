# @(#)$Id$

package Class::Usul::Build;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use parent qw(Module::Build);

use Class::Usul::Constants;
use Class::Usul::Programs;
use Class::Usul::Schema;
use Config;
use TryCatch;
use File::Spec;
use MRO::Compat;
use Perl::Version;
use Module::CoreList;
use Pod::Eventual::Simple;
use English         qw(-no_match_vars);
use File::Copy      qw(copy move);
use File::Find      qw(find);
use File::Path      qw(make_path);
use IO::Interactive qw(is_interactive);
use XML::Simple     ();

if ($ENV{AUTOMATED_TESTING}) {
   # Some CPAN testers set these. Breaks dependencies
   $ENV{PERL_TEST_CRITIC} = FALSE; $ENV{PERL_TEST_POD} = FALSE;
   $ENV{TEST_CRITIC     } = FALSE; $ENV{TEST_POD     } = FALSE;
}

my $ACTIONS       = [ qw(create_dirs create_files copy_files link_files
                         create_schema create_ugrps set_owner
                         set_permissions make_default restart_server) ];
my $ARRAYS        = [ qw(copy_files create_dirs
                         create_files credentials link_files run_cmds) ];
my $ATTRS         = [ qw(ask style path_prefix ver phase create_ugrps
                         process_owner setuid_root create_schema credentials
                         run_cmd make_default restart_server
                         restart_server_cmd built) ];
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
my $PARAGRAPH     = { cl => TRUE, fill => TRUE, nl => TRUE };
my $PREFIX_NORMAL = [ NUL, qw(opt)     ];
my $PREFIX_PERL   = [ NUL, qw(var www) ];

# Around these M::B actions

sub ACTION_build {
   my $self = shift; my $cfg = $self->read_config_file;

   $cfg->{built} or $self->ask_questions( $cfg );

   return $self->next::method();
}

sub ACTION_distmeta {
   my $self = shift;

   $self->update_changlog( $self->_dist_version );
   $self->write_license_file;

   return $self->next::method();
}

sub ACTION_install {
   my $self = shift; my $cfg = $self->read_config_file;

   $self->cli->info( 'Base path '.$self->set_base_path( $cfg ) );
   $self->next::method();

   # Call each of the defined actions
   $self->$_( $cfg ) for (grep { $cfg->{ $_ } } @{ $self->actions });

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

sub actions {
   # Accessor/mutator for the list of defined actions
   my ($self, $actions) = @_;

   defined $actions and $self->{_actions} = $actions;
   defined $self->{_actions} or $self->{_actions} = $ACTIONS;

   return $self->{_actions};
}

sub ask_questions {
   my ($self, $cfg) = @_;

   my $cli = $self->cli; $cli->pwidth( $cfg->{pwidth} );

   # Update the config by looping through the questions
   for my $attr (@{ $self->config_attributes }) {
      my $method = q(get_).$attr;

      $cfg->{ $attr } = $self->$method( $cfg );
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
   $self->update_changlog( $ver = $self->_dist_version );
   $self->commit_release( 'first '.__tag_from_version( $ver ) );
   $self->_rebuild_build;
   return;
}

sub cli {
   # Self initialising accessor for the command line interface object
   my $self = shift;

   $self->{_command_line_interface}
      or $self->{_command_line_interface} = Class::Usul::Programs->new
            ( { appclass => $self->module_name, n => TRUE } );

   return $self->{_command_line_interface};
}

sub commit_release {
   my ($self, $msg) = @_;

   my $vcs = $self->_vcs or return; my $cli = $self->cli;

   $vcs->commit( ucfirst $msg ) and $cli->say( "Committed $msg" );
   $vcs->error and $cli->say( @{ $vcs->error } );
   return;
}

sub config_attributes {
   # Accessor/mutator for the list of defined config attributes
   my ($self, $attrs) = @_;

   defined $attrs and $self->{_attributes} = $attrs;
   defined $self->{_attributes} or $self->{_attributes} = $ATTRS;

   return $self->{_attributes};
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

sub read_config_file {
   my $self = shift;
   my $cli  = $self->cli;
   my $path = $cli->catfile( $self->base_dir, $CFG_FILE );
   my $cfg;

   -f $path or $cli->fatal( "File $path not found" );

   try { $cfg = XML::Simple->new( ForceArray => $ARRAYS )->xml_in( $path ) }
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

sub update_changlog {
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
   my $cli          = $self->cli;
   my $path         = $cli->catfile( $self->base_dir, $CFG_FILE );

   defined $path or $cli->fatal( 'Config path undefined' );
   defined $cfg  or $cli->fatal( 'Config data undefined' );

   try {
      my $xs = XML::Simple->new
         ( NoAttr => TRUE, OutputFile => $path, RootName => q(config) );

      chmod oct q(0640), $path;
      $xs->xml_out( $cfg );
   }
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

# Questions

sub get_ask {
   my ($self, $cfg) = @_; is_interactive() or return FALSE;

   return $self->cli->yorn( 'Ask questions during build', TRUE, TRUE, 0 );
}

sub get_built {
   return TRUE;
}

sub get_create_schema {
   my ($self, $cfg) = @_; my $create = $cfg->{create_schema} || FALSE;

   $cfg->{ask} or return $create; my $cli = $self->cli;

   my $text = 'Schema creation requires a database, id and password';

   $cli->output( $text, $PARAGRAPH );

   return $cli->yorn( 'Create database schema', $create, TRUE, 0 );
}

sub get_create_ugrps {
   my ($self, $cfg) = @_; my $create = $cfg->{create_ugrps} || FALSE;

   $cfg->{ask} or return $create; my $cli = $self->cli; my $text;

   $text  = 'Use groupadd, useradd, and usermod to create the user ';
   $text .= $cfg->{owner}.' and the groups '.$cfg->{group};
   $text .= ' and '.$cfg->{admin_role};
   $cli->output( $text, $PARAGRAPH );

   return $cli->yorn( 'Create groups and user', $create, TRUE, 0 );
}

sub get_credentials {
   my ($self, $cfg) = @_; my $credentials = $cfg->{credentials} || {};

   return $credentials unless ($cfg->{ask} and $cfg->{create_schema});

   my $cli     = $self->cli;
   my $name    = $cfg->{database_name};
   my $etcd    = $cli->catdir ( $self->base_dir, qw(var etc) );
   my $path    = $cli->catfile( $etcd, $name.q(.xml) );
   my ($dbcfg) = $self->_get_connect_info( $path );
   my $prompts = { name     => 'Enter db name',
                   driver   => 'Enter DBD driver',
                   host     => 'Enter db host',
                   port     => 'Enter db port',
                   user     => 'Enter db user',
                   password => 'Enter db password' };
   my $defs    = { name     => $name,
                   driver   => q(_field),
                   host     => q(localhost),
                   port     => q(_field),
                   user     => q(_field),
                   password => NUL };

   for my $fld (qw(name driver host port user password)) {
      my $value = $defs->{ $fld } eq q(_field)
                ? $dbcfg->{credentials}->{ $name }->{ $fld }
                : $defs->{ $fld };

      $value = $cli->get_line( $prompts->{ $fld }, $value, TRUE, 0, FALSE,
                               $fld eq q(password) ? TRUE : FALSE );
      $fld eq q(password) and $value = $self->_encrypt( $cfg, $value, $etcd );
      $credentials->{ $name }->{ $fld } = $value;
   }

   return $credentials;
}

sub get_make_default {
   my ($self, $cfg) = @_; my $make_default = $cfg->{make_default} || FALSE;

   $cfg->{ask} or return $make_default;

   my $text = 'Make this the default version';

   return $self->cli->yorn( $text, $make_default, TRUE, 0 );
}

sub get_path_prefix {
   my ($self, $cfg) = @_; my $cli  = $self->cli;

   my $default = $cfg->{style} && $cfg->{style} eq q(normal)
               ? $PREFIX_NORMAL : $PREFIX_PERL;
   my $prefix  = $cfg->{path_prefix} || $cli->catdir( @{ $default } );

   $cfg->{ask} or return $prefix;

   my $text = 'Application name is automatically appended to the prefix';

   $cli->output( $text, $PARAGRAPH );

   return $cli->get_line( 'Enter install path prefix', $prefix, TRUE, 0 );
}

sub get_phase {
   my ($self, $cfg) = @_; my $phase = $cfg->{phase} || PHASE;

   $cfg->{ask} or return $phase; my $cli = $self->cli; my $text;

   $text  = 'Phase number determines at run time the purpose of the ';
   $text .= 'application instance, e.g. live(1), test(2), development(3)';
   $cli->output( $text, $PARAGRAPH );
   $phase = $cli->get_line( 'Enter phase number', $phase, TRUE, 0 );
   $phase =~ m{ \A \d+ \z }mx
      or $cli->fatal( "Phase value $phase bad (not an integer)" );

   return $phase;
}

sub get_process_owner {
   my ($self, $cfg) = @_; my $user = $cfg->{process_owner} || q(www-data);

   return $user unless ($cfg->{ask} and $cfg->{create_ugrps});

   my $cli = $self->cli; my $text;

   $text  = 'Which user does the web server/proxy run as? This user ';
   $text .= 'will be added to the application group so that it can ';
   $text .= 'access the application\'s files';
   $cli->output( $text, $PARAGRAPH );

   return $cli->get_line( 'Web server user', $user, TRUE, 0 );
}

sub get_restart_server {
   my ($self, $cfg) = @_; my $restart = $cfg->{restart_server} || FALSE;

   $cfg->{ask} or return $restart;

   return $self->cli->yorn( 'Restart web server', $restart, TRUE, 0 );
}

sub get_restart_server_cmd {
   my ($self, $cfg) = @_; my $cmd = $cfg->{restart_server_cmd} || NUL;

   return $cmd unless ($cfg->{ask} and $cfg->{restart_server});

   return $self->cli->get_line( 'Server restart command', $cmd, TRUE, 0 );
}

sub get_run_cmd {
   my ($self, $cfg) = @_; my $run = $cfg->{run_cmd} || FALSE;

   $cfg->{ask} or return $run; my $cli = $self->cli; my $text;

   $text  = 'Execute post installation commands. These may take ';
   $text .= 'several minutes to complete';
   $cli->output( $text, $PARAGRAPH );

   return $cli->yorn( 'Post install commands', $run, TRUE, 0 );
}

sub get_setuid_root {
   my ($self, $cfg) = @_; my $setuid = $cfg->{setuid_root} || FALSE;

   $cfg->{ask} or return $setuid; my $cli = $self->cli; my $text;

   $text   = 'Enable wrapper which allows limited access to some root ';
   $text  .= 'only functions like password checking and user management. ';
   $text  .= 'Not necessary unless the Unix authentication store is used';
   $cli->output( $text, $PARAGRAPH );

   return $cli->yorn( 'Enable suid root', $setuid, TRUE, 0 );
}

sub get_style {
   my ($self, $cfg) = @_; my $style = $cfg->{style} || q(normal);

   $cfg->{ask} or return $style; my $cli = $self->cli; my $text;

   $text  = 'The application has two modes if installation. In *normal* ';
   $text .= 'mode it installs all components to a specifed path. In ';
   $text .= '*perl* mode modules are install to the site lib, ';
   $text .= 'executables to the site bin and the rest to a subdirectory ';
   $text .= 'of /var/www. Installation defaults to normal mode since it is ';
   $text .= 'easier to maintain';
   $cli->output( $text, $PARAGRAPH );

   return $cli->get_line( 'Enter the install mode', $style, TRUE, 0 );
}

sub get_ver {
   my $self = shift;

   my ($major, $minor) = split m{ \. }mx, $self->dist_version;

   return $major.q(.).$minor;
}

# Actions

sub copy_files {
   # Copy some files
   my ($self, $cfg) = @_; my $cli = $self->cli; my $base = $cfg->{base};

   for my $ref (@{ $cfg->{copy_files} }) {
      my $from = $self->_abs_path( $base, $ref->{from} );
      my $path = $self->_abs_path( $base, $ref->{to  } );

      if (-f $from and not -f $path) {
         $cli->info( "Copying $from to $path" );
         copy( $from, $path );
         chmod oct q(0644), $path;
      }
   }

   return;
}

sub create_dirs {
   # Create some directories that don't ship with the distro
   my ($self, $cfg) = @_; my $cli = $self->cli; my $base = $cfg->{base};

   for my $dir (map { $self->_abs_path( $base, $_ ) }
                @{ $cfg->{create_dirs} }) {
      if (-d $dir) { $cli->info( "Directory $dir exists" ) }
      else {
         $cli->info( "Creating $dir" );
         make_path( $dir, { mode => oct q(02750) } );
      }
   }

   return;
}

sub create_files {
   # Create some empty log files
   my ($self, $cfg) = @_; my $cli = $self->cli; my $base = $cfg->{base};

   for my $path (map { $self->_abs_path( $base, $_ ) }
                 @{ $cfg->{create_files} }) {
      unless (-f $path) {
         $cli->info( "Creating $path" ); $cli->io( $path )->touch;
      }
   }

   return;
}

sub create_schema {
   # Create databases and edit credentials
   my ($self, $cfg) = @_; my $cli = $self->cli;

   # Edit the XML config file that contains the database connection info
   $self->_edit_credentials( $cfg );

   my $bind = $self->install_destination( q(bin) );
   my $cmd  = $cli->catfile( $bind, $cfg->{prefix}.q(_schema) );

   # Create the database if we can. Will do nothing if we can't
   $cli->info( $cli->run_cmd( $cmd.q( -n -c create_database) )->out );

   # Call DBIx::Class::deploy to create the
   # schema and populate it with static data
   $cli->info( 'Deploying schema and populating database' );
   $cli->info( $cli->run_cmd( $cmd.q( -n -c deploy_and_populate) )->out );
   return;
}

sub create_ugrps {
   # Create the two groups used by this application
   my ($self, $cfg) = @_; my $cli = $self->cli; my $base = $cfg->{base};

   my $cmd = q(/usr/sbin/groupadd); my $text;

   if (-x $cmd) {
      # Create the application group
      for my $grp ($cfg->{group}, $cfg->{admin_role}) {
         unless (getgrnam $grp ) {
            $cli->info( "Creating group $grp" );
            $cli->run_cmd( $cmd.q( ).$grp );
         }
      }
   }

   $cmd = q(/usr/sbin/usermod);

   if (-x $cmd and $cfg->{process_owner}) {
      # Add the process owner user to the application group
      $cmd .= ' -a -G'.$cfg->{group}.q( ).$cfg->{process_owner};
      $cli->run_cmd( $cmd );
   }

   $cmd = q(/usr/sbin/useradd);

   if (-x $cmd and not getpwnam $cfg->{owner}) {
      # Create the user to own the files and support the application
      $cli->info( 'Creating user '.$cfg->{owner} );
      ($text = ucfirst $self->module_name) =~ s{ :: }{ }gmx;
      $cmd .= ' -c "'.$text.' Support" -d ';
      $cmd .= $cli->dirname( $base ).' -g '.$cfg->{group}.' -G ';
      $cmd .= $cfg->{admin_role}.' -s ';
      $cmd .= $cfg->{shell}.q( ).$cfg->{owner};
      $cli->run_cmd( $cmd );
   }

   return;
}

sub link_files {
   # Link some files
   my ($self, $cfg) = @_; my $cli = $self->cli; my $base = $cfg->{base};

   for my $ref (@{ $cfg->{link_files} }) {
      my $from = $self->_abs_path( $base, $ref->{from} ) || NUL;
      my $path = $self->_abs_path( $base, $ref->{to  } ) || NUL;

      if ($from and $path) {
         if (-e $from) {
            -l $path and unlink $path;

            if (! -e $path) {
               $cli->info( "Symlinking $from to $path" );
               symlink $from, $path;
            }
            else { $cli->info( "Path $path already exists" ) }
         }
         else { $cli->info( "Path $from does not exist" ) }
      }
      else { $cli->info( "Path from $from or to $path undefined" ) }
   }

   return;
}

sub make_default {
   # Create the default version symlink
   my ($self, $cfg) = @_; my $cli = $self->cli; my $base = $cfg->{base};

   chdir $cli->dirname( $base );
   -e q(default) and unlink q(default);
   symlink $cli->basename( $base ), q(default);
   return;
}

sub restart_server {
   # Bump start the web server
   my ($self, $cfg) = @_; my $cli = $self->cli; my $cmd;

   return unless ($cmd = $cfg->{restart_server_cmd} and -x $cmd);

   $cli->info( "Running $cmd" );
   $cli->run_cmd( $cmd );
   return;
}

sub set_owner {
   # Now we have created everything and have an owner and group
   my ($self, $cfg) = @_; my $cli = $self->cli; my $base = $cfg->{base};

   my $gid = $cfg->{gid} = getgrnam( $cfg->{group} ) || 0;
   my $uid = $cfg->{uid} = getpwnam( $cfg->{owner} ) || 0;
   my $text;

   $text  = 'Setting owner '.$cfg->{owner}."($uid) and group ";
   $text .= $cfg->{group}."($gid)";
   $cli->info( $text );

   # Set ownership
   chown $uid, $gid, $cli->dirname( $base );
   find( sub { chown $uid, $gid, $_ }, $base );
   chown $uid, $gid, $base;
   return;
}

sub set_permissions {
   # Set permissions
   my ($self, $cfg) = @_; my $cli = $self->cli;

   my $base = $cfg->{base}; my $pref = $cfg->{prefix};

   chmod oct q(02750), $cli->dirname( $base );

   find( sub { if    (-d $_)                { chmod oct q(02750), $_ }
               elsif ($_ =~ m{ $pref _ }mx) { chmod oct q(0750),  $_ }
               else                         { chmod oct q(0640),  $_ } },
         $base );

   $cfg->{create_dirs} or return;

   # Make the shared directories group writable
   for my $dir (grep { -d $_ }
                map  { $self->_abs_path( $base, $_ ) }
                @{ $cfg->{create_dirs} }) {
      chmod oct q(02770), $dir;
   }

   return;
}

# Private methods

sub _abs_path {
   my ($self, $base, $path) = @_; my $cli = $self->cli;

   $cli->io( $path )->is_absolute or $path = $cli->catfile( $base, $path );

   return $path;
}

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
      my ($curr_dist, $module, $prev_dist); my $try_module = $used_key;

      while ($curr_dist = __dist_from_module( $try_module )
             and (not $prev_dist
                  or  $curr_dist->base_id eq $prev_dist->base_id)) {
         $module = $try_module;
         $prev_dist or $prev_dist = $curr_dist;
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
         my $modules = __parse_depends_line( $line ); $modules->[ 0 ] or next;

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

sub _edit_credentials {
   my ($self, $cfg) = @_; my $value;

   my $dbname = $cfg->{database_name} or return;

   return unless ($cfg->{credentials} and $cfg->{credentials}->{ $dbname });

   my $cli           = $self->cli;
   my $etcd          = $cli->catdir ( $cfg->{base}, qw(var etc) );
   my $path          = $cli->catfile( $etcd, $dbname.q(.xml) );
   my ($dbcfg, $dtd) = $self->_get_connect_info( $path );
   my $credentials   = $cfg->{credentials}->{ $dbname };

   for my $fld (qw(driver host port user password)) {
      defined ($value = $credentials->{ $fld }) or next;
      $dbcfg->{credentials}->{ $dbname }->{ $fld } = $value;
   }

   try {
      my $io = $cli->io( $path );
      my $xs = XML::Simple->new( NoAttr => TRUE, RootName => q(config) );

      $dtd and $io->println( $dtd );
      $io->append( $xs->xml_out( $dbcfg ) );
   }
   catch ($e) { $cli->fatal( $e ) }

   return;
}

sub _encrypt {
   my ($self, $cfg, $value, $dir) = @_;

   $value or return; my $cli = $self->cli; my $path;

   my $args = { seed => $cfg->{secret} || $cfg->{prefix} };

   $dir and $path = $cli->catfile( $dir, $cfg->{prefix}.q(.txt) );
   $path and -f $path and $args->{data} = $cli->io( $path )->all;
   $value = Class::Usul::Schema->encrypt( $args, $value );
   $value and $value = q(encrypt=).$value;

   return $value;
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

sub _get_arrays_from_dtd {
   my ($self, $dtd) = @_; my $arrays = [];

   my $pattern = q(<!ELEMENT \s+ (\w+) \s+ \( \s* ARRAY \s* \) \*? \s* >);

   for my $line (split m{ \n }mx, $dtd) {
      $line =~ m{ \A $pattern \z }imsx and push @{ $arrays }, $1;
   }

   return $arrays;
}

sub _get_connect_info {
   my ($self, $path) = @_;

   my $cli    = $self->cli;
   my $text   = $cli->io( $path )->all;
   my $dtd    = join "\n", grep {  m{ <! .+ > }mx } split m{ \n }mx, $text;
      $text   = join "\n", grep { !m{ <! .+ > }mx } split m{ \n }mx, $text;
   my $arrays = $self->_get_arrays_from_dtd( $dtd );
   my $info;

   try { $info = XML::Simple->new( ForceArray => $arrays )->xml_in( $text ) }
   catch ($e) { $cli->fatal( $e ) }

   return ($info, $dtd);
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

   return [ grep { m{ (?: \.pm | \.t | \.pl ) \z }imx
                   || $cli->io( $_ )->getline
                         =~ m{ \A \#! (?: .* ) perl (?: \s | \z ) }mx }
            map  { s{ \s+ }{ }gmx; (split SPC, $_)[0] }
            $cli->io( $MANIFEST_FILE )->chomp->getlines ];
}

sub _update_version {
   my ($self, $from, $to) = @_;

   my $cli   = $self->cli;
   my $prog  = $EXECUTABLE_NAME;
   my $cmd   = "'s{ \Q${from}\E \\.%d    }{${to}.%d}gmx;";
      $cmd  .= " s{ \Q${from}\E \\.\$Rev }{${to}.\$Rev}gmx'";
      $cmd   = [ q(xargs), q(-i), $prog, q(-pi), q(-e), $cmd, q({}) ];
   my $paths = [ map { "$_\n" } @{ $self->_source_paths } ];

   $cli->popen( $cmd, { err => q(out), in => $paths } );
   return;
}

sub _vcs {
   my $self = shift; my $class = __PACKAGE__.q(::VCS); my $vcs;

   my $dir  = ref $self ? $self->cli->config->{appldir} : File::Spec->curdir;

   ref $self and $vcs = $self->{_vcs} and return $vcs;

   $vcs = $class->new( $dir ); ref $self and $self->{_vcs} = $vcs;

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

sub __looks_like_version {
    my $ver = shift;

    return defined $ver && $ver =~ m{ \A v? \d+ (?: \.[\d_]+ )? \z }mx;
}

sub __parse_depends_line {
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
responses are saved to the F<build.xml> file. The L</config_attributes>
method returns the list of questions to ask

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

=head2 cli

   $cli = $builder->cli;

Returns an instance of L<Class::Usul::Programs>, the command line
interface object

=head2 config_attributes

   $current_list_of_attrs = $builder->config_attributes( $new_list_of_attrs );

This accessor/mutator method defaults to the list defined in the C<$ATTRS>
package variable

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

=head2 read_config_file

   $config = $builder->read_config_file( $path );

Reads the configuration information from F<$path> using L<XML::Simple>.
The package variable C<$ARRAYS> is passed to L<XML::Simple> as the
I<ForceArray> attribute. Called by L</ACTION_build> and L<ACTION_install>

=head2 replace

   $builder->replace( $this, $that, $path );

Substitutes C<$this> string for C<$that> string in the file F<$path>

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

=head2 write_config_file

   $config = $builder->write_config_file( $path, $config );

Writes the C<$config> hash to the F<$path> file for later use by
the install action. Called from L<ACTION_build>

=head1 Questions

All question methods are passed C<$config> and return the new value
for one of it's attributes

=head2 get_ask

Ask if questions should be asked in future runs of the build process

=head2 get_built

Always returns true. This dummy question is used to trigger the suppression
of any further questions once the build phase is complete

=head2 get_create_schema

Should a database schema be created? If yes then the database connection
information must be entered. The database must be available at install
time

=head2 get_create_ugrps

Create the application user and group that owns the files and directories
in the application

=head2 get_credentials

Get the database connection information

=head2 get_make_default

When installed should this installation become the default for this
host? Causes the symbolic link (that hides the version directory from
the C<PATH> environment variable) to be deleted and recreated pointing
to this installation

=head2 get_path_prefix

Prompt for the installation prefix. The application name and version
directory are automatically appended. If the installation style is
B<normal>, the all of the application will be installed to this
path. The default is F</opt>. If the installation style is B<perl>
then only the "var" data will be installed to this path. The default is
F</var/www>

=head2 get_phase

The phase number represents the reason for the installation. It is
encoded into the name of the application home directory. At runtime
the application will load some configuration data that is dependent
upon this value

=head2 get_process_owner

Prompts for the userid of the web server process owner. This user will
be added to the group that owns the application files and directories.
This will allow the web server processes to read and write these files

=head2 get_restart_server

When the application is mostly installed, should the web server be
restarted?

=head2 get_restart_server_cmd

What is the command used to restart the web server

=head2 get_run_cmd

Run the post installation commands? These may take a long time to complete

=head2 get_setuid_root

Enable the C<setuid> root wrapper?

=head2 get_style

Which installation layout? Either B<perl> or B<normal>

=over 3

=item B<normal>

Modules, programs, and the F<var> directory tree are installed to a
user selectable path. Defaults to F<< /opt/<appname> >>

=item B<perl>

Will install modules and programs in their usual L<Config> locations. The
F<var> directory tree will be install to F<< /var/www/<appname> >>

=back

=head2 get_ver

Dummy question returns the version part of the installation directory

=head1 Actions

All action methods are passed C<$config>

=head2 copy_files

Copies files as defined in the C<< $config->{copy_files} >> attribute.
Each item in this list is a hash ref containing I<from> and I<to> keys

=head2 create_dirs

Create the directory paths specified in the list
C<< $config->{create_dirs} >> if they do not exist

=head2 create_files

Create the files specified in the list
C<< $config->{create_files} >> if they do not exist

=head2 create_schema

Creates a database then deploys and populates the schema

=head2 create_ugrps

Creates the user and group to own the application files

=head2 link_files

Creates some symbolic links

=head2 make_default

Makes this installation the default for this server

=head2 restart_server

Restarts the web server

=head2 set_owner

Set the ownership of the installed files and directories

=head2 set_permissions

Set the permissions on the installed files and directories

=head1 Private Methods

=head2 _abs_path

   $absolute_path = $builder->_abs_path( $base, $path );

Prepends F<$base> to F<$path> unless F<$path> is an absolute path

=head2 _copy_file

   $builder->_copy_file( $source, $destination );

Called by L</process_files>. Copies the C<$source> file to the
C<$destination> directory

=head2 _edit_credentials

   $builder->_edit_credentials( $config, $dbname );

Writes the database login information stored in the C<$config> to the
application config file in the F<var/etc> directory. Called from
L</create_schema>

=head2 _encrypt

   $encrypted_value = $self->_encrypt( $config, $plain_value, $dir )

Returns the encrypted value the plain value. Called from
L</get_credentials>

=head2 _get_arrays_from_dtd

   $list_of_arrays = $builder->_get_arrays_from_dtd( $dtd );

Parses the C<$dtd> data and returns the list of element names which are
interpolated into arrays. Called from L</_get_connect_info>

=head2 _get_connect_info

   ($info, $dtd) = $builder->_get_connect_info( $path );

Reads database connection information from F<$path> using L<XML::Simple>.
The I<ForceArray> attribute passed to L<XML::Simple> is obtained by parsing
the DTD elements in the file. Called by the L</get_credentials> question
and L<_edit_credentials>

=head1 Diagnostics

None

=head1 Configuration and Environment

Edits and stores config information in the file F<build.xml>

=head1 Dependencies

=over 3

=item L<Class::Usul::Programs>

=item L<Class::Usul::Schema>

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
