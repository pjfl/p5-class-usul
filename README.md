# Name

Class::Usul - A base class providing config, locking, logging, and l10n

# Version

Describes Class::Usul version v0.21.$Rev: 1 $

# Synopsis

    use Class::Usul::Moose;

    extends qw(Class::Usul);

    $self = Class::Usul->new( $attr );

# Description

These modules provide a set of base classes for Perl packages and
applications that provide configuration file loading
[Class::Usul::Config](https://metacpan.org/module/Class::Usul::Config), locking to single thread processes
[IPC::SRLock](https://metacpan.org/module/IPC::SRLock), logging [Class::Usul::Log](https://metacpan.org/module/Class::Usul::Log) and localization
[Class::Usul::L10N](https://metacpan.org/module/Class::Usul::L10N)

The class [Class::Usul::Programs](https://metacpan.org/module/Class::Usul::Programs) is a base class for command line interfaces

Interprocess communication is handled by [Class::Usul::IPC](https://metacpan.org/module/Class::Usul::IPC)

[Class::Usul::File](https://metacpan.org/module/Class::Usul::File) makes the functionality of [File::DataClass](https://metacpan.org/module/File::DataClass) available

The [Module::Build](https://metacpan.org/module/Module::Build) subclass [Class::Usul::Build](https://metacpan.org/module/Class::Usul::Build) adds methods for the
management and deployment of applications

[Class::Usul::Moose](https://metacpan.org/module/Class::Usul::Moose) is a custom [Moose](https://metacpan.org/module/Moose) exporter

# Configuration and Environment

Defines the following attributes;

- config

    The `config` attribute should be a hash ref that may define key/value pairs
    that provide filesystem paths for the temporary directory etc.

- config\_class

    Defaults to [Class::Usul::Config](https://metacpan.org/module/Class::Usul::Config) and is of type `LoadableClass`. An
    instance of this class is loaded and instantiated using the hash ref
    in the `config` attribute. It provides accessor methods with symbol
    inflation and smart defaults. Add configuration attributes by
    subclassing the default

- debug

    Defaults to false

- encoding

    Decode input and encode output. Defaults to `UTF-8`

Defines an instance of [IPC::SRLock](https://metacpan.org/module/IPC::SRLock)

Defines the application context log. Defaults to a [Log::Handler](https://metacpan.org/module/Log::Handler) object

# Subroutines/Methods

## new\_from\_class

    $usul_object = $self->new_from_class( $application_class ):

Returns a new instance of self starting only with an application class name.
The application class in expected to provide `config` and `debug` class
methods. The hash ref `$application_class->config` will be passed as
the `config` attribute to the constructor for this class

## dumper

    $self->dumper( $some_var );

Use [Data::Printer](https://metacpan.org/module/Data::Printer) to dump arguments for development purposes

## \_build\_\_lock

Defines the lock object. This instantiates on first use

An [IPC::SRLock](https://metacpan.org/module/IPC::SRLock) object which is used to single thread the
application where required. This is a singleton object.  Provides
defaults for and returns a new [IPC::SRLock](https://metacpan.org/module/IPC::SRLock) object. The keys of the
`$self->config->lock_attributes` hash are:

- debug

    Debug status. Defaults to `$self->debug`

- log

    Logging object. Defaults to `$self->log`

- tempdir

    Directory used to store the lock file and lock table if the `fcntl` backend
    is used. Defaults to `$self->config->tempdir`

# Diagnostics

Setting the _debug_ attribute to true causes messages to be logged at the
debug level

# Dependencies

- [Class::Usul::Constants](https://metacpan.org/module/Class::Usul::Constants)
- [Class::Usul::Functions](https://metacpan.org/module/Class::Usul::Functions)
- [Class::Usul::L10N](https://metacpan.org/module/Class::Usul::L10N)
- [Class::Usul::Log](https://metacpan.org/module/Class::Usul::Log)
- [Class::Usul::Moose](https://metacpan.org/module/Class::Usul::Moose)
- [IPC::SRLock](https://metacpan.org/module/IPC::SRLock)

# Incompatibilities

There are no known incompatibilities in this module

# Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

# Author

Peter Flanigan, `<pjfl@cpan.org>`

# Acknowledgements

Larry Wall - For the Perl programming language

# License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/module/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
