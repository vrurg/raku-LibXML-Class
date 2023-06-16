NAME `LibXML::Class::Document` - document object
================================================

DESCRIPTION
===========

The concept of `LibXML::Class` document is mostly covered in [`LibXML::Class::Manual`](Manual.md).

Attributes
----------

  * **`LibXML::Document $.libxml-document`**

    The instance of deserialized [`LibXML`](https://modules.raku.org/dist/LibXML) document.

  * **`LibXML::Class::Config:D $.config`**

    An instance of `LibXML::Class` configuration object. Defaults to the global singleton.

Methods
-------

  * **`proto method parse(|)`**

      * **`multi method parse(::?CLASS:U: LibXML::Class::Config :$config, |args)`**

        This methods creates a new instance of `LibXML::Class::Document` using either the provided `$config`, or the global singleton. Then `$config.libxml-config` is used to get the class of `LibXML` document using `class-from` method and then call `parse` method on the class with arguments in `args`.

        At the end a new `LibXML::Class` document is created using the parsed `LibXML` document and the config object.

      * **`multi method parse(::?CLASS:D: |args)`**

        Create a new `$.libxml-document` by using `$.config.libxml-config` and calling method `parse` with arguments in `args`. Returns the invocator.

  * **`method add-deserialization(LibXML::Class::XML:D $deserialization)`**

    Unless disabled by the configuration, adds `$deserialization` to the document registry for fast hash-indexed search.

  * **`proto method has-deserialization(|)`**

      * **`multi method has-deserialization(LibXML::Element:D $element)`**

        Tells if there is an entry for the `$element` in the global registry.

      * **`multi method has-deserialization(Str:D $unique-key)`**

        Tells if there is an entry for the `$unique-key` in the global registry.

  * **`method deserializations(LibXML::Element:D $element)`**

    Returns all deserializations registered for the `$element`, or an empty list if there is none.

  * **`method remove-deserialization(LibXML::Class::XML:D $deserialization)`**

    Removes the `$deserialization` from the global registry.

  * **`proto method find-deserializations(|)`**

      * **`method find-deserializations(LibXML::Node:D $node)`**

      * **`method find-deserializations(Iterable:D $nodes)`**

    Returns a list of deserializations for a `$node` or multiple `$nodes`. When lazy operations are on and a node is not deserialized yet then the method tries to determine the path to the node and deserialize it, possibly deserializing all its parents along the way.

  * **`method findnodes(|args)`**

    This is a wrapper method which first calls `$.libxml-document.findnodes(|args)` and then sends all found nodes to the `find-deserializations` method.

    Returns a `LibXML::Class::X::Deserialization::NoBacking` [`Failure`](https://docs.raku.org/type/Failure) if there is no `$.libxml-document` meaning that the object is not a result of deserialization.

SEE ALSO
========

  * [*README*](../../../../README.md)

  * [`LibXML::Class::Manual`](Manual.md)

  * [`LibXML::Class`](../Class.md)

  * [`LibXML::Class::XML`](XML.md)

COPYRIGHT
=========

(c) 2023, Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the [*LICENSE*](../../../../LICENSE) file in this distribution.

