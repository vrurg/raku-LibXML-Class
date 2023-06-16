NAME `LibXML::Class::Attr::XMLContainer` - XML-containerizeable `xml-element` attributes
========================================================================================

DESCRIPTION
===========

This is the base role for attribute descriptors capable of implementing `:container` parameter of `xml-element` trait.

Attribute
---------

  * **`$.container`**

    Can be either [`Bool`](https://docs.raku.org/type/Bool) or [`Str`](https://docs.raku.org/type/Str). In the latter case the value is a name of container XML element.

Methods
-------

  * **`method outer-name()`**

    Returns either container name, or `$.xml-name`. In either case, it is the outermost XML element name of this attribute's serialization.

  * **`method container-name()`**

    Returns *Nil* if attribute is not containerized. Otherwise it would be either `$.container` when it's a string, or `$.xml-name`.

  * **`method value-name(Mu $value?)`**

    Returns XML name of value element for this attribute. When there is no container the name would be just `$.xml-name`. With a container value type is determined either from `$value`, if passed in, or from attribute's nominal type. The type is used to determine the name and *Nil* would be returned if the type is a basic one.

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

