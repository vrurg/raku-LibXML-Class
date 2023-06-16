NAME
====

`LibXML::Class` – general purpose XML de-/serialization for Raku

SYNOPSIS
========

Simple Case
-----------

```raku
use LibXML::Class;

class Record1 is xml-element {
    has Int:D $.id is required;
    has Str $.description;
    has %.meta;
}

my $rec = Record1.new(:id(1000), :description("test me"), :meta{ key1 => π, key2 => "some info" });

say $rec.to-xml.Str(:format);
```

This would result in:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Record1 id="1000" description="test me">
  <meta>
    <key1>3.141592653589793e+00</key1>
    <key2>some info</key2>
  </meta>
</Record1>
```

More Complex Case
-----------------

```raku
use LibXML::Class;
use Test::Async;

class Record2 is xml-element( :ns<http://my.namespace> ) {
    has Int:D $.id is required is xml-attribute;
    has Str:D $.description is required is xml-attribute;
    has Str $.comment is xml-element(:value-attr<text>, :ns( :extra ) );
    has Real:D $.amount is required is xml-element;
    has DateTime $.when; # Not part of XML
}

class METAEntry is xml-element {
    has Str:D $.key is required;
    has Str:D $.value is required;
}

role META is xml-element {
    has METAEntry @.meta-entry is xml-element('entry', :container<meta>);
}

class Registry is xml-element('registry', :ns( :extra<http://additional.namespace> )) does META {
    has Record2 @.record is xml-element;
}

my $root = Registry.new;
$root.record.append:
    Record2.new( :id(1001),
                 :description("item1"),
                 :comment("here comes a comment"),
                 :amount(42.12) ),
    Record2.new( :id(1002),
                 :description("item2"),
                 :amount(0) );

$root.meta-entry.append:
    METAEntry.new(:key<version>, :value<1.1a>),
    METAEntry.new(:key<encoding>, :value<utf-8>);

my $xml = $root.to-xml;

diag $xml.Str(:format);

my $root-copy = Registry.from-xml: $xml.Str;

cmp-deeply $root-copy, $root, "both are the same";
```

The output of this would be like:

    # <?xml version="1.0" encoding="UTF-8"?>
    # <registry xmlns:extra="http://additional.namespace">
    #   <record xmlns="http://my.namespace" id="1001" description="item1">
    #     <extra:comment text="here comes a comment"/>
    #     <amount>42.12</amount>
    #   </record>
    #   <record xmlns="http://my.namespace" id="1002" description="item2">
    #     <amount>0</amount>
    #   </record>
    #   <meta>
    #     <entry key="version" value="1.1a"/>
    #     <entry key="encoding" value="utf-8"/>
    #   </meta>
    # </registry>
    #
    ok 1 - both are the same
    1..1

DESCRIPTION
===========

Primary documentation for this module can be found in [`LibXML::Class::Manual`](Class/Manual.md). Here we would only focus on a couple of technical details.

A Quick Note On Deserialization
-------------------------------

Whereas serialization is not that complex, after all, deserialization proves to be much trickier, espcially when it comes to implementing lazy operations. The information in this section would only prove useful if you plan to somehow "participate" in this party.

Deserialization is split into two major steps. The first one is building a profile for object constructor. At this step we only know our outer deserialization context (think of it as if we know about our parent and how it is deserializing), the current element we're about to deserialize, and the target class, an instance of which will represent the element in Raku. When profile building is done (i.e. we have a `%profile` hash with all necessary keys) we instantiate the class using its `xml-create` method:

```raku
TargetClass.xml-create: |%profile
```

The second step is not clearly localized in time as it might happen when the profile is being built, or later (up to never at all) if lazy operations are in effect. Either way, this step is about the *actual* deserialization from the XML source. It takes place individually for every entity like attribute of sequence item.

Attributes Of `xml-element` Class
---------------------------------

A few attributes that `xml-element` trait would introduce onto your XMLized type object that might be useful on occasion.

*Note* that attributes listed here are actually private. Public access to them is provided via plain old methods.

  * **`Int:D` `$.xml-id`**

    Unique ID of this deserialization. Cloning creates a new ID.

  * **`LibXML::Class::Document` `$.xml-document`**

    A document object. May remain undefined for manually created instances. For deserializations this is the glue which binds them all together and to the source `LibXML::Document`.

  * **`LibXML::Element` `$.xml-backing`**

    The XML element that's been deserialized to produce this instance.

  * **`$.xml-dctx`**

    Returns deserialization context instance. When lazy operations are disabled or all lazy elements have been deserialized, resulting in dropping of the context, attribute value is undefined.

  * **`$.xml-unused`**

    A list of [`LibXML`](https://modules.raku.org/dist/LibXML) AST nodes representing XML nodes not used in deserialization of this instance.

  * **`$.xml-unique-key`**

    Shortcut to `$.xml-backing.unique-key`.

Dynamic Variables
-----------------

The serialization and deserialization processes are, apparently, very much context-dependent. Therefore a couple of dynamic variables are used to maintain and provide current context state.

  * **`$*LIBXML-CLASS-CONFIG`**

    Current context configuration instance.

  * **`$*LIBXML-CLASS-CTX`**

    Context object. Currently serialization doesn't require specific context, but deserialization is using this variable. Deserialization context API would be documented later in this document.

  * **`$*LIBXML-CLASS-ELEMENT`**

    The `LibXML::Element` instance currently being de-/serialized. Might be useful for a custom de-/serializer code.

  * **`%*LIBXML-CLASS-OVERRIDE`**

    Don't toy with this one unless you *do know* what are you doiing!

    Only used by deserialization. Content of this hash is used to override nested context prefix definitions. Whatever prefixes are proivided with this dynamic would override anything `xml-from-element` method finds in its outer deserialization context, or in the defaults.

Methods Of `xml-element` Class
------------------------------

Methods available on an `xml-element`-traited class.

  * **`proto method to-xml(|)`**

      * **`multi method to-xml(Str :$name, Str :ns(:namespace(:$xml-default-ns)), Str :prefix(:$xml-default-ns-pfx), :$config)`**

      * **`multi method to-xml(LibXML::Document:D $doc, Str :$name, Str :ns(:namespace(:$xml-default-ns)), Str :prefix(:$xml-default-ns-pfx), :$config)`**

      * **`multi method to-xml(LibXML::Element:D $elem, Str :ns(:namespace(:$xml-default-ns)), Str :prefix(:$xml-default-ns-pfx), :$config)`**

    Serializes an `xml-element` class. The default without a positional argument would return full `LibXML::Document` instance.

    With `$doc` or `$elem` positionals an `LibXML::Element` would be returned. The only difference is that for `$doc` case the element would be created on the document provided. Otherwise the object would serialize into `$elem`.

    The named arguments are:

      * `$name` would override the target element name; not used when `$elem` is passed in

      * `$xml-default-ns` would force the default namespace of the XML element

      * `$xml-default-ns-pfx` would force the default namespace prefix

      * `$config` can be either an instance of [`LibXML::Class::Config`](Class/Config.md), or a hash of config parameters

  * **`proto method from-xml(|)`**

      * **`multi method from-xml(IO:D $source, *%nameds)`**

      * **`multi method from-xml(Str:D $source-xml, *%nameds)`**

      * **`multi method from-xml(Str:D $source-xml, LibXML::Class::Document:D :$document!, *%nameds)`**

      * **`multi method from-xml(LibXML::Document:D $libxml-document, LibXML::Class::Config:D :$config!, *%nameds)`**

      * **`multi method from-xml(LibXML::Element:D $elem, LibXML::Class::Document:D $document?, Str :$name, Str :ns(:namespace(:$xml-default-ns)), Str :prefix(:$xml-default-ns-pfx), :$config, :%user-profile)`**

    Deserialize and create an instance of the class-invocant of the method.

    Named arguments are mostly the same for each multi-candidate except for the ones where `LibXML::Class::Document` instance is known and where `$config` just doesn't make sense because we have it on the document:

      * `$name` overrides the expected element name when the element we deserialize from has a name different from invocant's default.

      * `$xml-default-ns`, `$xml-default-ns-pfx` override the namespace parameters if we know that the ones of the source element are different from class defaults.

      * `$config` can be either an instance of [`LibXML::Class::Config`](Class/Config.md), or a hash of config parameters

      * `%user-profile` is used as additional named arguments for the `new` constructor method of not the invocant class alone but for all deserializations of its child elements.

  * **`method xml-name()`**

    Returns element name of the invocant. For a class/role it would be their default name.

  * **`method xml-class()`**

    Returns the actual XMLized class. This method provides easy access to the type object which provides all defaults if the invocant is a non-XMLized subclass.

  * **`method xml-config()`**

    Returns current context `LibXML::Class::Config` instance.

  * **`method xml-has-lazies()`**

    Returns *True* if any lazy entities are undeserialized yet.

  * **`method xml-serialize-stages()`**, **`method xml-profile-stages()`**

    De-/serialization can be a multi-stage process. The simplest case is for plain XMLized classes where there is just one stage. XML sequence requires two stages to do it. These methods must return lists of method names implementing each stage. If you wish to add some custom processing then the best solution would be to inject your own stage to a list by overriding a method or both.

    **Note** that the second method is not named `xml-deserialize-stages` because this is not exactly about deserialization as such.

  * **`method xml-new-dctx(*%profile)`**

    Returns a new deserialization context using constructor profile in `%profile`.

  * **`method xml-create(*%profile)`**

    This method is used by `LibXML::Class` to create and new instance of an `xml-elemnt` class when it's done building a constructor method `%profile`. The default version of it simply redirect to the standard method `new`, but [`LibXML::Class::Config`](Class/Config.md) is overriding it for manually XMLized classes to produce an instance of the original, non-XMLized, class as the result of deserialization.

  * **`method xml-add-deseializarion(LibXML::Node:D $node, Mu $representation)`**

    Registers `$representation` as a deserialization for the `LibXML` `$node`. This makes the representation searchable with `LibXML::Class::Document` `findnodes` or `find-deserializations` methods.

  * **`proto method xml-deserializations(|)`**

      * **`multi method xml-deserializations(LibXML::Node:D $node)`**

      * **`multi method xml-deserializations(Str:D $unique-key)`**

    Returns a list of deserializations registered for the `$node`, or for a node with `$unique-key` with `xml-add-deserialization`. Returns [`Nil`](https://docs.raku.org/type/Nil) if there is nothing.

  * **`proto method xml-has-deserializations(|)`**

      * **`multi method xml-has-deserializations(LibXML::Node:D $node)`**

      * **`multi method xml-has-deserializations(Str:D $unique-key)`**

    Returns *True* if there is at least one deserialization registered for a `$node` or a `$unique-key`.

  * **`proto method xml-remove-deserialization(|)`**

      * **`multi method xml-remove-deserialization(LibXML::Class::XMLObject:D $representation)`**

      * **`multi method xml-remove-deserialization(Str:D $unique-key, Mu $representation)`**

    Remove a deserialization from the registry. Normally this is only to be done when it is about to be destroyed.

  * **`method xml-findnodes(|c)`**

    This method is equivalent to [`LibXML::Class::Document`](Class/Document.md) `findnodes` method expect that the undelying [`LibXML`](https://modules.raku.org/dist/LibXML) method of the same name is invoked on the deserialization's backing element in `$.xml-backing`. If for any reason there is no backing the method returns a [`Failure`](https://docs.raku.org/type/Failure) with `LibXML::Class::X::Deserialize::NoBacking` exception.

  * **`method xml-lazy-deserialize-context(&code)`**

    This methods invokes a code object in `&code` within dynamic context where `$*LIBXML-CLASS-CTX` and `$*LIBXML-CLASS-CONFIG` are set. When the `&code` finishes the method checks if all lazies have been deserialized already and drops the deserialization context if they have.

    Returns the result of `&code` invocation.

    `LibXML::Class::X::Deserialize::NoCtx` is thrown if there is no context.

  * **`method xml-deserialize-attr(Str:D :$attribute!)`**

    This method implements lazy deserialization of a Raku `$attribute`. It is normally invoked by [`AttrX::Mooish`](https://modules.raku.org/dist/AttrX::Mooish) upon accessing a lazy attribute.

    This is a multi-dispatch method, but the other candidates are implementation detail. It is highly recommended to only override this method in a subclass (your `xml-element` class, normally) to do some pre- or post-processing for deserialization.

  * **`proto method xml-serialize-attr(LibXML::Element:D $elem, LibXML::Class::Attr::XMLish:D $descriptor)`**

    Similarly to the `xml-deserialize-attr` method, this one is rather an implementation detail and only recommended for pre- or post-processing in a subclass. `$elem` is the destination element for serialization of the value in a Raku attribute.

  * **`method xml-to-element(LibXML::Element:D $elem, ... --> LibXML::Element:D)`**, **`method xml-from-element(LibXML::Element:D $elem, LibXML::Class::Document:D $doc, ...)`**

    Both methods are implementation details not to be invoked directly. But they're good candidates to do pre-/post-processing as these are the final destinations methods `to-xml` and `from-xml` call. Basically consider the latter two as API frontends only.

    In both cases `$elem` is the [`LibXML`](https://modules.raku.org/dist/LibXML) representation of our `xml-element` class-invocant.

### Methods Available For XML Sequence Types

Sequence types provide basic methods one would expect for [`Positional`](https://docs.raku.org/type/Positional) and [`Iterable`](https://docs.raku.org/type/Iterable). If a traditional method is not implemented then either it isn't compatible with XML sequences or it could be implemented in the future; perhaps, by a request.

  * **`method xml-serialize-item(LibXML::Element:D $elem, LibXML::Class::ItemDescriptor:D $desc, Mu $value)`**

    Method serializes a sequence item `$value` into XML sequence element `$elem`. The method returns serialized XML element representing the `$value` and adds it to the XML sequence element as a child.

  * **`method xml-deserialize-item(LibXML::Element:D $elem, LibXML::Class::ItemDescriptor:D $desc, UInt:D :$index, *%nameds)`**

    This method implements lazy deserialization of XML sequence item from XML element `$elem`. `$index` is the element position in the sequence.

    Returns deserialized value.

Exports
-------

### Traits

This module exports the following traits:

  * `is xml-element`

  * `is xml-attribute`

  * `is xml-text`

They're documented in [`LibXML::Class::Manual`](Class/Manual.md).

### `xml-I-cant`

This is just a shortcut for throwing a control exception which causes user-provided de-/serializer code to give up and let the module do the job. See more details in the [`Manual`](Class/Manual.md).

Cloning
-------

Cloning a deserialized object isn't a trivial task, especiall when lazy operations are in effect. A custom `clone` method overrides Raku's default which does some preparation before calling the parent method. When done `post-clone` method gets invoked. The default post-clone procedure includes registering a new deserialization for the source XML element.

SEE ALSO
========

  * [*README*](../../../../README)

  * [`LibXML::Class::Manual`](Class/Manual.md)

COPYRIGHT
=========

(c) 2023, Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the [*LICENSE*](../../../../LICENSE) file in this distribution.

