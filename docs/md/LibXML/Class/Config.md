NAME `LibXML::Class::Config` – configure `LibXML::Class` de-/serialization process
==================================================================================

SYNOPSIS
========

```raku
use LibXML::Class::Config :types;

my $config = LibXML::Class::Config.new: :eager, :severity(STRICT); # Disable lazy opeations

my $deserialization = MyXMLRepresentation.from-xml: $xml-source, :$config;
```

Or:

```raku
my $deserialization = MyXMLRepresentation.from-xml: $xml-source, config => %( :eager, :severity<STRICT> );
```

DESCRIPTION
===========

Topics, related to configuring your `LibXML::Class` operations are mainly covered in [`LibXML::Class::Manual`](Manual.md). Here only a few technical details are covered.

Exported Types
--------------

With `use LibXML::Class::Config :types;` statement auxiliary configuration type objects are exported into the user's namespace. Though for the moment only one such type is available, `SerializeSeverity`. It is an enum providing values for `severity` parameter: `EASY`, `WARN`, and `STRICT`.

Configuration Parameters
------------------------

Configuration parameter values are held in attributes on `LibXML::Class::Config` instance.

  * **`SerializeSeverity:D $.severity = WARN`**

    Sometimes problems, occuring during de-serialization, are not necessarily fatal. Severity defines how `LibXML::Class` reacts to them. When it is *EASY* then errors a plain ignored; with *WARN* they are reported and ignored; with *FATAL* expections are thrown.

    When we create a new config object, or pass a configuration profile hash into methods, `severity` key can be set to a string representation of one of these values.

  * **`Bool:D $.eager = False`**

    Turn off lazy operations. Doesn't apply to XML sequences.

  * **`Bool $.derive.attribute = False`**, **`Bool $.derive.element = False`**

    This parameter configures XML namespace deriving, as described in [`LibXML::Class::Manual`](Manual.md). Can be set as a single value like, for example, `:derive(True)`.

  * **`Bool:D $.deserialization-registry = True`**

    Enable or disable keeping registries of deserialized objects. Disabling it also means disabling search functionality.

  * **`Bool:D $.global-index = True`**

    If disabled then [`LibXML::Class::Document`](Document.md) object doesn't keep global index of deserialized `xml-element` instances. This doesn't affect search capbilities, but may slow down them.

  * **`LibXML::Config:D $.libxml-config`**

    An instance of default `LibXML::Config`.

Methods
-------

  * **`method document-class()`**

    Returns a class to be used to create a default document object. Normally it is [`LibXML::Class::Document`](Document.md), but can be overriden when necessary.

  * **`method libxml-config-class()`**

    Returns a class for `$.libxml-config` parameter. Normally it is the standard `LibXML::Config`, but can be overriden.

  * **`method build-libxml-config()`**

    `$.libxml-config` is an [`AttrX::Mooish`](https://modules.raku.org/dist/AttrX::Mooish) lazy and this method is its builder. By default it creates an instance of `self.libxml-config-class()` with `:with-cache` parameter set.

  * **`method global(*%c)`**

    When invoked for the first time it creates a singleton instance of `LibXML::Class::Config` serving as the default for other instances of configuration. If any named argument is passed into the method at this point it is used to set a parameter; i.e. `%c` serves as the constructor profile.

    Any subsequent call just returns the singleton. By then any attempt to pass an argument will cause `LibXML::ClasS::X::Config::ImmutableGlobal` exception to be throw.

  * **`proto method alert($)`**

      * **`multi method alert(Str:D $message)`**

      * **`multi method alert(Exception:D $exception)`**

    Depending on what `$.severity` is set to would either keep silence, or `warn`, or throw the `$exception`. If just a `$message` submitted then it is wrapped into `LibXML::Class::X::AdHoc` first.

  * **`proto method set-ns-map(|)`**

    This method is used to setup mapping between namespaces and types available for XML:any entities. More details are available in [`LibXML::Class::Manual`](Manual.md). Here we only iterate over method candidates.

    Most of the candidates of this method are to provide flexibilty in the source data structure when declaring namespaces. For example, these are all the same:

    ```raku
    LibXML::Class::Config.new: ns-map => %( 'ns' => { "elem-name" => ElemType, } );
    LibXML::Class::Config.new: ns-map => ( 'ns' => ( "elem-name" => ElemType, ) );
    LibXML::Class::Config.new: ns-map => ( ('ns', "elem-name", ElemType ), );
    ```

    Depending on where one gets their information about the maps from, they can produce the most convenient input for the parameter.

      * **`multi method set-ns-map(Str:D $namespace, Str:D $xml-name, Mu:U $type)`**

        This is the base candidate which adds a map for element named `$xml-name` into `$type` to the `$namespace`. In the above example the last format matches directly into this candidate. With that format if you want to add more mappings then you'd need to repeat them individually:

            (
                ('ns', "elem1", ElemType1),
                ('ns', "elem2", ElemType2),
            )

      * **`multi method set-ns-map(*%ns-map)`**

        Setup from named arguments.

      * **`multi method set-ns-map(%ns-map)`**

        Setup from a hash.

      * **`multi method set-ns-map(@ns-map)`**

        Setup from a list of entries.

      * **`multi method set-ns-map(Str:D $namespace, *@entries, *%map)`**

        Set for `$namespace` using positional and named arguments as map entries.

      * **`multi method set-ns-map(LibXML::Class::Node:U $type)`**

        Add `$type` using its default namespace and element name.

      * **`multi method set-ns-map(Str:D $namespace, LibXML::Class::Node:U $type)`**

        Similar to the previous candidate but override the namespace.

      * **`method set-ns-map(Str:D $namespace, Pair:D $entry)`**

        Add an individual `<elem-name> => ElemType` entry for the `$namespace`.

    See examples of using `ns-map` in [*manual09.raku*](../../../../examples/manual09.raku), [*manual10.raku*](../../../../examples/manual10.raku), [*040-basic-serialization.rakutest*](../../../../t/040-basic-serialization.rakutest), [*050-sequential.rakutest*](../../../../t/050-sequential.rakutest).

SEE ALSO
========

  * [*README*](../../../../README)

  * [`LibXML::Class::Manual`](Class/Manual.md)

  * [`LibXML::Class`](../Class.md)

COPYRIGHT
=========

(c) 2023, Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the [*LICENSE*](../../../../LICENSE) file in this distribution.

