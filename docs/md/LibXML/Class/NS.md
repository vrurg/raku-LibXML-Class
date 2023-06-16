NAME `LibXML::Class::NS` - base role for namespace-aware classes
================================================================

DESCRIPTION
===========

This role implements the most basic namespace functionality which includes:

  * default namespace value

  * default namespace prefix value

  * map of namespace prefixes into namespaces

Attributes
----------

  * **`Str $.xml-default-ns`**

    The default namespace value, when set.

  * **`Str $.xml-default-ns-pfx`**

    The default namespace prefix, when set.

  * **`OHash:D $.xml-namespaces`**

    An ordered hash of namespace prefix values. `OHash` is an internal implementation provided by [`LibXML::Class::Types`](Types.md).

### Methods

  * **`method xml-set-ns-from-defs($ns-defs, Bool:D :$override = True)`**

    This method sets up namespace information from declarations in `$ns-defs`, as described in [`LibXML::Class::Manual`](Manual.md), where named argument `:namespace` (or `:ns`) is described.

  * **`method xml-guess-default-ns(LibXML::Node :$resolve)`**

    This method does the most basic job in trying to find out what namespace applies to the object. It is using only the information provided by the object itself. When guessing `$.xml-default-ns` is ignored if `$.xml-default-ns-pfx` is set. And if the prefix cannot be resolved using the local definitions in `$.xml-namespaces` then it tries to use the `$resolve` parameter, if provided.

    When no namespace can be found a [`Failure`](https://docs.raku.org/type/Failure) is returned wrapped around `LibXML::Class::X::NS::Prefix` exception.

SEE ALSO
========

  * [*README*](../../../../README.md)

  * [`LibXML::Class::Manual`](Manual.md)

  * [`LibXML::Class`](../Class.md)

COPYRIGHT
=========

(c) 2023, Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the [*LICENSE*](../../../../LICENSE) file in this distribution.

