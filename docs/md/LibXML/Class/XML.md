NAME `LibXML::Class::XML` - base role for all de-/serializable classes
======================================================================

DESCRIPTION
===========

Required Methods
----------------

```raku
method clone-from(Mu:D) {...}
method from-xml(|) {...}
method to-xml(|) {...}
method xml-name(--> Str:D) {...}
method xml-backing {...}
method xml-deserialize-node(|) {...}
method xml-deserialize-element(|) {...}
```

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

