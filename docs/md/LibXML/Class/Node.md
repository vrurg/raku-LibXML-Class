NAME `LibXML::Class::Node` - base role of types, that can be XML-named and aware of namespacing
===============================================================================================

DESCRIPTION
===========

This role consumes [`LibXML::Class::NS`](NS.md).

Attributes
----------

  * **`Str:D $.xml-name`**

    A lazy attribute, initialized from a return value of `xml-build-name` method. While the method is not explicitly required by the role (there are some compile-time issues arrise if it does), but it has to be implemented by a consuming class.

Methods
-------

  * **`method xml-has-name()`**

    A predicate, reporting if `$.xml-name` has been initialized already.

  * **`method xml-apply-ns(LibXML::Element:D $dest-elem, Bool:D :$default = True, Str :namespace(:xml-default-ns(:$ns)), Str :xml-default-ns-pfx(:$prefix), :$config = $*LIBXML-CLASS-CONFIG)`**

    Assuming that current object is being serialized into `$dest-elem` this method applies namespace information to the element, based on what is set for the object itself. This means:

      * adding all prefix definitions from `$.xml-namespaces` to the element

      * finding out namespace default value and prefix

      * resolving the previous values and setting them on the element

    Namespace default and prefix passed in as `$ns` and `$prefix` arguments would override what is set for the object itself even when just one is set. This is a common rule when defining either of two is considered as if both are set, even if the other one is undefined.

    If no namespace is explicitly passed in the arguments and `$default` is *True* the corresponding object attributes are taken.

    If the default namespace by now is set and is not empty then it's used as is. An empty one is resolved from `$dest-elem` by looking up the empty prefix *""* – this is how the default namespace is propagaded from parent XML elements.

    If the prefix is set we also try to resolve it first on the `$dest-elem`. Don't forget that by now we've already applied all locally defined namespace prefixes to the element making the overall picture complete. If the prefix cannot be resolved then either `$config.alert` is used to report the problem, or `LibXML::Class::X::NS::Prefix` is thrown unconditionally. Resolved prefix gets added to the element too.

SEE ALSO
========

  * [*README*](../../../../README.md)

  * [`LibXML::Class::Manual`](Manual.md)

  * [`LibXML::Class`](../Class.md)

  * [`LibXML::Class::NS`](NS.md)

COPYRIGHT
=========

(c) 2023, Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the [*LICENSE*](../../../../LICENSE) file in this distribution.

