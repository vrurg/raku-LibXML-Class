NAME `LibXML::Class::Attr::XMLValueElement` - descriptor for all `xml-element` attributes
=========================================================================================

DESCRIPTION
===========

Consumes [`LibXML::Class::Attr::Node`](Node.md) and [`LibXML::Class::Attr::XMLContainer`](XMLContainer.md).

This is the base descriptor for any attribute serializable as an XML element. [`LibXML::Class::Attr::XMLPositional`](XMLPositional.md) and [`LibXML::Class::Attr::XMLAssociative`](XMLAssociative.md) are both children of this class.

Attribute
---------

  * **`Str $.value-attr`**

    If set then XML attribute with this name must be used to hold serialized value.

Method
------

  * **`method is-any()`**

    Returns *True* if this attribute is an XML:any. See [`LibXML::Class::Manual`](../Manual.md).

SEE ALSO
========

  * [*README*](../../../../../README.md)

  * [`LibXML::Class::Manual`](../Manual.md)

  * [`LibXML::Class`](../../Class.md)

  * [`LibXML::Class::Attr`](../Attr.md)

COPYRIGHT
=========

(c) 2023, Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the [*LICENSE*](../../../../LICENSE) file in this distribution.

