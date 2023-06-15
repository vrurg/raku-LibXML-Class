NAME `LibXML::Class::Attr::XMLish` - base role of all attribute [`descriptors|../Descriptor.md`](`descriptors|../Descriptor.md`)
================================================================================================================================

DESCRIPTION
===========

Attributes
----------

  * **`Attribute:D $.attr`**

    The Raku attribute of this descriptor.

  * **`Bool $.lazy`**

    If this attribute must be lazily deserialized. Note that if not explicitly set then laziness flags of this attribute would be computed based on attribute's type and [`LibXML::Class::Config`](../Config.md) `eage` parameter.

  * **`Mu:U $.value-type`**

    What an XML representation would be deserialized into? For [`Positional`](https://docs.raku.org/type/Positional) or [`Associative`](https://docs.raku.org/type/Associative) attributes this is the type provided by `$.attr.type.of`.

    **Note** that to be considered positional or associative the attribute must have corresponding sigil. Say, `has Positional $.foo` is not positional for `LibXML::Class`.

  * **`Mu:U $.nominal-type`**

    Nominalization of `$.value-type`.

Methods
-------

  * **`method sigil()`**

    Attribute's sigil.

Required Methods
----------------

  * **`method kind(--` Str:D) {...}**>

    Return the most concise description of attribute descriptor. For example, *"value element"*.

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

