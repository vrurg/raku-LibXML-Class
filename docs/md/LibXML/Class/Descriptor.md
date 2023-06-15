NAME
====

`LibXML::Class::Descriptor` – base role for attribute and XML sequence items descriptors

DESCRIPTION
===========

Descriptor is an object which provides all necessary information to de-/serialize an object stored in an attribute or an XML sequence item. Correspondingly, there are two kinds of descriptors: for attributes, and for sequence items. When we refer to them a common term *entity* could be used where it doesn't matter what exactly a descriptor represents.

Consumes [`LibXML::Class::Node`](Node.md).

Attributes
----------

  * **`&.serializer`**

    User-provided serializer code object.

  * **`&.deserializer`**

    User-provided deserializer code object.

  * **`Bool $.derive`**

    Flag, indicating that the entity must derve its namespace information.

  * **`Mu $.declarant`**

    The type object which declares the entity. Say, for:

    ```raku
    class Foo is xml-element {
        has $.attr is xml-element;
    }
    ```

    `Foo` is the declarant of `$.attr`.

Methods
-------

### Required by this role

These methods must be implemented by the actual descriptor classes:

  * **`method nominal-type`**

    Must return entitity's nominal type. Let's say we have a declaration of `has Type:D() $.attr` somewhere. The nominal type of `$.attr` would be `Type`.

  * **`method value-type`**

    The type into which XML representation of this entity must deserialize into.

  * **`method config-derive`**

    Config parameter for namespace deriving for this particular kind of entity. See [`LibXML::Class::Config`](Config.md) and [`LibXML::Class::Manual`](Manual.md).

  * **`method descriptor-kind`**

    Returns a string describing the current entity. The string can be used for error reporting, for example, or for debug printing.

### API

  * **`method has-serializer()`**

    Do we have a user-provided serializer?

  * **`method has-deserializer()`**

    Do we have a user-provided deserializer?

  * **`method serializer-cando(|args)`**

    Returns *True* if user serializer is set and can be used with the `args`.

  * **`method deserializer-cando(|args)`**

    Returns *True* if user deserializer is set and can be used with the `args`.

  * **`method infer-ns(Mu :$from, Str :$default-ns, Str :$default-pfx)`**

    Method tries to infer entity's default namespace and prefix. The rules of computing entity namespace are described in [`LibXML::Class::Manual`](Manual.md).

  * **`method type-check(Mu \value, $when)`**

    Makes sure that the `value` is type checking OK against the `value-type`. If it doesn't then `LibXML::Class::X::TypeCheck` is thrown.

    `$when` is used for exception error message. If it is a [`Code`](https://docs.raku.org/type/Code) then the object gets called and the result is expected to be a string; otherwise the object is coerced into the [`Str`](https://docs.raku.org/type/Str) and then used. The code trick is useful for cases where generating a stringifiable value is too expensive and only worth doing at the moment when the actual exception is about to be thrown.

SEE ALSO
========

  * [*README*](../../../../README)

  * [`LibXML::Class::Manual`](Class/Manual.md)

  * [`LibXML::Class`](../Class.md)

  * [`LibXML::Class::Config`](Config.md)

COPYRIGHT
=========

(c) 2023, Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the [*LICENSE*](../../../../LICENSE) file in this distribution.

