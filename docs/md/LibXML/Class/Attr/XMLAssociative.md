NAME `LibXML::Class::Attr::XMLAssociative` - descriptor for associative `xml-element` attributes
================================================================================================

DESCRIPTION
===========

Inherits from [`LibXML::Class::Attr::XMLValueElement`](XMLValueElement.md).

An associative attribute is the one which type is [`Associative`](https://docs.raku.org/type/Associative) and the sigil is *%*.

Method
======

  * **`method nominal-keyof()`**

    Returns nominalized type of associative keys. I.e. for `has %.attr{ Int:D() }` this method would return [`Int`](https://docs.raku.org/type/Int).

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

