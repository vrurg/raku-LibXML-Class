NAME `LibXML::Class::Attr::XMLTextNode` - descriptor for `xml-text` attributes
==============================================================================

DESCRIPTION
===========

Consumes [`LibXML::Class::Attr::Node`](Node.md), but doesn't support namespacing and would throw `LibXML::Class::X::Attr::NoNamespace` if any of namespace-related methods is called.

Attribute
=========

  * **`Bool $.trim`**

    If *True* then the text from XML would be trimmed. Remember that despite the text content of an XML element is collected from all its `#text` nodes, only the white spaces at the start and at the end are trimmed. I.e., for the following node:

    ```xml
    <elem>
        <foo />
        word1
        <bar />
        word2
        <baz />
    </elem>
    ```

    The resulting text after trimming would be *"word1\n \n word2"*. This is not a big deal as de-/serialization must normally operate over non-formatted XML files. Otherwise most common use for this flag would be for simple cases like this one:

    ```xml
    <someValue>
        Indented text
    </someValue>
    ```

SEE ALSO
========

  * [*README*](../../../../README.md)

  * [`LibXML::Class::Manual`](Class/Manual.md)

  * [`LibXML::Class`](../Class.md)

COPYRIGHT
=========

(c) 2023, Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the [*LICENSE*](../../../../LICENSE) file in this distribution.

