<div>
    <a href="https://travis-ci.org/pjfl/p5-class-usul"><img src="https://travis-ci.org/pjfl/p5-class-usul.svg?branch=master" alt="Travis CI Badge"></a>
    <a href="http://badge.fury.io/pl/Class-Usul"><img src="https://badge.fury.io/pl/Class-Usul.svg" alt="CPAN Badge"></a>
    <a href="http://cpants.cpanauthors.org/dist/Class-Usul"><img src="http://cpants.cpanauthors.org/dist/Class-Usul.png" alt="Kwalitee Badge"></a>
</div>

# Name

Class::Usul - A base class providing config, locking, logging, and l10n

# Version

Describes Class::Usul version v0.71.$Rev: 1 $

# Synopsis

    use Class::Usul;
    use Class::Usul::Constants qw( FALSE );
    use Class::Usul::Functions qw( find_apphome get_cfgfiles );

    my $attr = { config => {} }; my $conf = $attr->{config};

    $conf->{appclass    } or  die "Application class not specified";
    $attr->{config_class} //= $conf->{appclass}.'::Config';
    $conf->{home        }   = find_apphome $conf->{appclass};
    $conf->{cfgfiles    }   = get_cfgfiles $conf->{appclass}, $conf->{home};

    return Class::Usul->new( $attr );

# Description

These modules provide a set of base classes for Perl modules and
applications. It provides configuration file loading
[Class::Usul::Config](https://metacpan.org/pod/Class::Usul::Config), locking to single thread processes
[IPC::SRLock](https://metacpan.org/pod/IPC::SRLock), logging [Class::Usul::Log](https://metacpan.org/pod/Class::Usul::Log) and localisation
[Class::Usul::L10N](https://metacpan.org/pod/Class::Usul::L10N)

The class [Class::Usul::Programs](https://metacpan.org/pod/Class::Usul::Programs) is a base class for command line interfaces

Interprocess communication is handled by [Class::Usul::IPC](https://metacpan.org/pod/Class::Usul::IPC)

[Class::Usul::File](https://metacpan.org/pod/Class::Usul::File) makes the functionality of [File::DataClass](https://metacpan.org/pod/File::DataClass) available

# Configuration and Environment

Defines the following attributes;

- `config`

    The `config` attribute should be a hash reference that may define key / value
    pairs that provide filesystem paths for the temporary directory etc.

- `config_class`

    Defaults to [Class::Usul::Config](https://metacpan.org/pod/Class::Usul::Config) and is of type `LoadableClass`. An
    instance of this class is loaded and instantiated using the hash reference
    in the `config` attribute. It provides accessor methods with symbol
    inflation and smart defaults. Add configuration attributes by
    subclassing this class

- `debug`

    A boolean which defaults to false. Usually an instance of this class is passed
    into the constructors of other classes which set their own debug state to this
    value

- `l10n`

    A lazily evaluated instance of the `l10n_class`. This object reference is a
    [Localiser](https://metacpan.org/pod/Class::Usul::Types#Localiser) which handles the `localize` method

- `l10n_class`

    A lazy loadable class which defaults to [Class::Usul::L10N](https://metacpan.org/pod/Class::Usul::L10N)

- `lock`

    A lazily evaluated instance of the `lock_class`. This object reference is a
    [Locker](https://metacpan.org/pod/Class::Usul::Types#Locker)

- `lock_class`

    A lazy loadable class which defaults to [IPC::SRLock](https://metacpan.org/pod/IPC::SRLock)

- `log`

    A lazily evaluated instance of the `log_class`. This object reference is a
    [Logger](https://metacpan.org/pod/Class::Usul::Types#Logger)

- `log_class`

    A lazy loadable class which defaults to [Class::Usul::Log](https://metacpan.org/pod/Class::Usul::Log)

# Subroutines/Methods

## `dumper`

    $self->dumper( $some_var );

Use [Data::Printer](https://metacpan.org/pod/Data::Printer) to dump arguments for development purposes

# Diagnostics

Setting the _debug_ attribute to true causes messages to be logged at the
debug level

# Dependencies

- [Class::Usul::Config](https://metacpan.org/pod/Class::Usul::Config)
- [Class::Usul::Constants](https://metacpan.org/pod/Class::Usul::Constants)
- [Class::Usul::Functions](https://metacpan.org/pod/Class::Usul::Functions)
- [Class::Usul::L10N](https://metacpan.org/pod/Class::Usul::L10N)
- [Class::Usul::Log](https://metacpan.org/pod/Class::Usul::Log)
- [Class::Usul::Types](https://metacpan.org/pod/Class::Usul::Types)
- [IPC::SRLock](https://metacpan.org/pod/IPC::SRLock)
- [Moo](https://metacpan.org/pod/Moo)

# Incompatibilities

There are no known incompatibilities in this module

# Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Usul. Patches are
welcome

# Author

Peter Flanigan, `<pjfl@cpan.org>`

# Acknowledgements

Larry Wall - For the Perl programming language

# License and Copyright

Copyright (c) 2016 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
