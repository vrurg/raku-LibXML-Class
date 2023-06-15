NAME `LibXML::Class::ItemDescriptor` - XML sequence item descriptor
===================================================================

DESCRIPTION
===========

This role consumes [`LibXML::Class::Descriptor`](Descriptor.md).

Attributes
----------

  * **`Mu $.type`**

    Item type. Say, for a declaration like `:sequence(:elem(Int:D))` the type is `Int:D`.

  * **`Str $.value-attr`**

    If the item serializes into an XML attribute then this is attribute's name.

SEE ALSO
========

  * [*README*](../../../../README)

  * [`LibXML::Class::Manual`](Class/Manual.md)

  * [`LibXML::Class`](../Class.md)

  * [`LibXML::Class::Descriptor`](Descriptor.md)

COPYRIGHT
=========

(c) 2023, Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the [*LICENSE*](../../../../LICENSE) file in this distribution.

