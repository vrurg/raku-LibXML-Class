`LibXML::Class` MANUAL
======================

DISCLAIMERS
-----------

  * [`LibXML::Class`](docs/md/LibXML/Class.md) is not capable of handling every possible variation of XML files. Despite all the efforts taken to cover as many possible cases as possible, serializing of Raku objects into XML is and likely will remain its primary purpose. And yet the module is expected to be capable of properly deserializing many different formats into Raku.

  * Due to its extensive nature, this manual is created in mainly write-only mode, with very limited proof-reading and other time-consuming luxuries. My deepest apologies for all the errors, but the priorities don't give me many choices.

  * Some concepts here may resemble what is familiar to you by [`XML::Class`](https://modules.raku.org/dist/XML::Class) implementation. This is because up to some extent `LibXML::Class` has been inspired by it. Yet, the differences are way to significant, so don't let yourself fall into the trap of "Ah, I already know what's this is about!"

Kick-start
----------

The fastest way to start using `LibXML::Class` is to apply bare `xml-element` trait to a class or role:

```raku
class Record is xml-elemnt {
    has Int:D $.id is required;
    has Str:D $.comment is required;
    has Num $.amount;
}
```

And you're all set! Now, at anytime an instance `$record` of `Record` can be serialized into `LibXML::Document` by calling `to-xml` method on it:

```raku
say $record.to-xml;
```

In a slightly more complex case a class attribute can store an instance of another `xml-element` class:

```raku
class Root is xml-element {
    has Record:D $.record is required;
}
```

See [*manual01.raku*](../../../../examples/manual01.raku) in the [*examples*](../../../../examples) directory.

### Roles

Not only classes but roles too can be declared as `xml-element`. Depending on the way a role is used the effect could differ.

Consuming an `xml-element` role by a plain class turns it into a serializable explicit class. See more in the [Implicit Or Explicit Declarations](#implicit-or-explicit-declarations) section about explicitness.

Consuming such role by a `xml-element` class would simply extend it with role's functionality while allowing the role to maintain control over some serialization aspects like, for example, namespaces.

See [*manual02.raku*](../../../../examples/manual02.raku) and [*manual03.raku*](../../../../examples/manual03.raku).

API Naming
----------

The way [`LibXML::Class`](../Class.md) works in the above example is by adding a role to the type object `xml-element` trait is used with. With the role a parent class `LibXML::Class::XMLObject` is added too. Normally these implementation details must not bother you, but they worth mentioning from the point of view that a lot of extra methods become available on the instances of `xml-element` classes.

In order to minimize possible conflicts or side effects, it's been taken into account that the XML standard forbids node names that start with `xml` prefix. Therefore nearly every method or attribute name, would it be public or private, declared by `LibXML::Class` classes or roles, are starting with `xml-`. Moreover, in some cases of implicit actions taken by `LibXML::Class` user attributes, starting same `xml-` prefix, are skipped and wouldn't be de-/serialized.

There are only two exceptions: methods `to-xml` and `from-xml`, but these are rather part of more common convention within Raku ecosystem. Besides, it'd be ugly to have a call like `$obj.xml-to`.

Some Terminology
----------------

  * **Basic types**

    As a very rough first approach we can say that for [`LibXML::Class`](../Class.md) a basic type is the one which trivially stringifies and into which we can trivially coerce from a string. These include [`Numeric`](https://docs.raku.org/type/Numeric), [`Stringy`](https://docs.raku.org/type/Stringy), [`Dateish`](https://docs.raku.org/type/Dateish), and [`Enumeration`](https://docs.raku.org/type/Enumeration) consuming types; also [`Bool`](https://docs.raku.org/type/Bool), [`Mu`](https://docs.raku.org/type/Mu), and [`Any`](https://docs.raku.org/type/Any).

    Depending on the context, terms *'complex'*, *'user defined'*, or alike can be used toward non-basic types.

  * **XMLized** type object

    A type object which can be XML de-/serialized. In technical terms of [`LibXML::Class`](../Class.md) this means it consumes `LibXML::Class::XMLRepresentation` role. Being XMLized means slightly different thing than *'`xml-element` type object'* because the latter is only about classes or roles with `xml-element` trait applied, whereas XMLization also applies to implicitly converted classes like in the abovementioned case of consuming an `xml-element` role.

  * **XML sequence**, **XML sequential**

    This term has its roots in *.xsd* schemas of [ECMA-376](https://www.ecma-international.org/publications-and-standards/standards/ecma-376) standard. A sequential XML element is a [`Positional`](https://docs.raku.org/type/Positional) (in terms of Raku) container. For example:

    ```xml
    <my-seq>
      <rec1>val1</rec1>      <!-- #0 -->
      <rec2 value="foo1" />  <!-- #1 -->
      <rec2 value="foo2" />  <!-- #2 -->
      <rec1>val2</rec1>      <!-- #3 -->
      <rec1>val1</rec1>      <!-- #4 -->
    </my-seq>
    ```

  * **Value element**

    An XML element representing a value. The most typical cases are `<amount val="42.12"/>` and `<amount>42.12</amount>`. In more complex cases, when the value, represented by the element, is not of a basic type, the element could has more attributes and child elements.

  * **XML container**, **XML containerization**

    It is the XML element wrapped around a value element, or series of elements. For example:

    ```xml
    <container>
       <val-element>42</val-element>
    </container>
    ```

    A container is serialized from a single entity and, correspondigly, deserialize into a single one too. I.e. the above example could end up as value *42* in `$.val-element`.

  * **Descriptors**

    Whenever we declare an `xml-element` type object we need to tell the module what subsidiary entities of the type object are de-/serializable too. There are currently two kinds of them: Raku attributes and items of an XML sequence representations. For every such entity a descriptor gets created which contains all information necessary to deal with the object.

  * **Declarant**

    Used in the context of descriptors primarily. A type object which declares a Raku attribute of a sequence item.

Exported Traits
---------------

[`LibXML::Class`](../Class.md) exports three traits to mark Raku objects as XML-serializable:

  * The aforementioned `xml-element` for the entities (type object or attributes) that correspond to XML elements

  * `xml-attribute`, which can only be used with class/role attributes, to result in an XML element attribute

  * `xml-text` is also a Raku attribute-only trait for *#text*; there can only be single such attribute per object

*Note* that an `xml-text` Raku attribute is not limited to stringy types only. It can be of any type for each either coercion from [`Str`](https://docs.raku.org/type/Str) is implemented or custom de-/serializers are defined.

For example:

```raku
class Record is xml-element {
    has Str $.attr is xml-attribute;
    has Str $.content is xml-text;
}

say Record.new(:attr<something>, :content("line1\nline2")).to-xml;
# <?xml version="1.0" encoding="UTF-8"?>
# <Record attr="something">line1
# line2</Record>
```

Both `xml-element` and `xml-attribute` traits share similar signatures: `:(Str:D $name?, *%named)` – where `$name` is element/attribute name to be used for XML representation. If omitted then see the section [XML Nodes Naming Conventions](#xml-nodes-naming-convention) below. The allowed named arguments vary depending on the context and object the trait is applied to.

`xml-text` doesn't take any positional argument but also shares a few named ones with the other two traits.

### XML Nodes Naming Conventions

The order in which a XML node gets its name is defined by the rules in this section. The rules differ for each of `xml-attribute` and `xml-element` traits.

For `xml-attribute` everything is simple:

  * if an explicit name is provided as trait's only positional argument then this name is used

  * otherwise attribute's base name (with no sigil and twigil) is taken

Things are somewhat less simple for `xml-element`. First of all, looking ahead, let's mention that when serializaing an attribute as XML element it is possible to specifiy that we want it to be wrapped into a special tag we call 'container'. [Containerization](#Containers) will have its own section down below in this manual, so for now we just need to know about it.

  * if an explicit name is provided as trait's positional argument then it is used

  * otherwise attribute's base name without sigil and twigil is used

  * if attribute is not containerized or container has an explicit name then we're done

  * otherwise if container has no name (i.e. the named argument is boolean `:container`) then

    * the name developed at the first two steps is used for the container element

    * if attribute's value type is an `xml-element` then it's name is taken

    * if the type is not an `xml-element` then its short name (`.^shortname`) is used

When an `xml-element` type object is an XML sequence we would also need to give names to its items. The rules for them are basically the same as for attributes with the only exception that items cannot be containerized.

### Type Object `xml-element` Named Arguments

When `xml-element` is used with a class or a role the following named arguments can be used:

  * `:implicit`

    A boolean specifying if typeobject arguments are to be implicitly serialized. Can be negated. See the section [Implicit Or Explicit Declarations](#implicit-or-explicit-declarations).

  * `:lazy`

    A boolean, turn on or off lazy deserialization.

  * `:namespace(...)` or `:ns(...)`

    This argument is in charge of XML namespaces. See the [Namespaces](#Namespaces) section.

  * `:impose-ns`

    If this boolean is *True* then any attribute not having its own `:ns` argument would use defaults for namespaces of its declarant. See the [Namespaces](#Namespaces) section.

  * `:sequence`

    This argument turns the type object into an XML sequence. See more details in [XML Sequence Objects](#xml-sequence-objects).

  * `:any`

    This boolen only makes sense when used with a `:sequence` argument. It allows very flexible way of defining and determening sequence items value types. See the [XML:any](#xmlany) section.

When `xml-element` is used with a class more named arguments become available:

  * `:derive`

    Turns on or off attribute namespace deriving mode. See the section [Namespaces](#Namespaces).

  * `:severity`

    Only used when the class is used as the root element of XML document. Sets severity mode of [`LibXML::Class::Config`](Config.md) configuration.

### Attribute Traits Named Arguments

All three attribute traits: `xml-element`, `xml-attribute`, and `xml-text` – share a few named arguments:

  * `:lazy`

    Boolean, enforce lazy deserialization for the attribute.

  * `:&serializer`, `:&deserializer`

    User provided serialization/deserialization.

The following arguments are shared by `xml-element` and `xml-attribute`:

  * `:namespace(...)`, `:namespace`, or as `:ns` alias

    This argument defines what namespaces are to used with XML node serialized from the attribute. See the [Namespaces](#Namespaces) section.

  * `:derive`

    Boolean that controls namespace deriving for individual attribute.

The following arguments are specific to `xml-element`:

  * `:value-attr(Str:D)` or `:attr(Str:D)` alias

    Normally a basic type would serialize into an XML element with `#text` node representing its value. With this argument an XML attribute would be used instead of `#text`. For example, with `:value-attr<val>` `$.bar` in the example above would become `<bar val="bar value"/>`.

  * `:any`

    Marks attribute as [XML:any](#xmlany).

  * `:container(Str:D|Bool:D)`

    Marks the attribute as XML-containerized. If given a string value like `:container<celem>` then it defines container XML element name at the same time. See the [Containers](#Containers) section.

### Parameter Application Order

Since some of trait parameters are overlapping the question of priorities arises. There is nothing complex here as the rule of thumb says: attribute or sequence item is the head of its all. So, if in doubt – set it on the attribute/item.

If a parameter is not explicitly specified for the attribute/item the module check up with either its declarant or its target type, if the target is an `xml-element`. Which one is used depends on the particular parameter and mostly it's rather intuitive to guess.

The configuration's advise could be used when none of the above provides a concrete answer. For example, when finding out about lazy deserialization `LibXML::Class` may refer to config's `eager` parameter.

Implicit Or Explicit Declarations
---------------------------------

When `xml-element` trait is applied to a type object by default it tries to use *implicit* mode meaning that all attributes of the object are marked as serializable. A typical example of implicit class is the example in the [Kick-start](Kick-start) section above.

Contrary, with `:!implicit` argument the object is set to explicit mode where only explicitly marked attributes are serializable. For example:

```raku
class Foo is xml-element(:!implicit) {
    has Int $.foo;
    has Str $.bar;
}
```

Neither `$.foo` nor `$.bar` would not be serialized into XML. But:

```raku
class Foo is xml-element(:!implicit) {
    has Int $.foo;
    has Str $.bar is xml-element;
}
```

Here we would still miss the `$.foo` attribute, though a value in `$.bar` would end up in an XML representation of `Foo` (if set to something defined, of course).

Normally, there is no need to use `:!implicit` as every time we mark an attribute with any of `xml-element`, `xml-attribute`, or `xml-text` the type object is automatically gets its implicitness turned off. This is also what happens when an `xml-element` role is consumed by a non-`xml-element` class, as it was mentioned in [Roles](#Roles).

There is a reson to use `:implicit` explicitly (no pun meant!) when declaring a type object. It makes sense if one wants all attributes to be auto-serialized except for few they want to give some special properties to:

```raku
class Foo is xml-element(:implicit) {
    has Int $.foo;
    has Str $.bar is xml-element;
}
```

In this example both attributes would get serialized if set. But `$.foo` would become an XML attribute, and `$.bar` would be an XML element (see [*manual04.raku*](../../../../examples/manual04.raku)):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Foo foo="42">
  <bar>textual value</bar>
</Foo>
```

Document Object
---------------

Somewhat similarly to [`LibXML`](https://modules.raku.org/dist/LibXML), `LibXML::Class` has a concept of *document object*. Contrary to `LibXML`, it is not sitting on the top of the object hierarchy. Instead its purpose is to serve as a helper and as a keeper of data, common for objects serialized from the same source. Currently a document knows about:

  * `LibXML` document of the source

  * [`LibXML::Class::Config`](Config.md) configuration object

  * Deserialization registry

The document object also provides the services of maintaining the deserialization registry and finding deserializations for XML nodes of the source.

Config
------

A configuration object controls de-/serialization properties, common for certain scope. Normally the scope is source XML document.

Often times it might be necessary to work with same kind of documents where the same configuration makes total sense to be used. To simplify handling of such situations there is a singleton configuration object accessible via [`LibXML::Class::Config`](Config.md) class method `global`. To pre-configure it one can call the method with necessary parameters:

```raku
LibXML::Class::Config.global(:eager);
```

The singleton can be initialized just once. Due to methods `to-xml` and `from-xml` implicitly vivifying the global config it's better to make sure that the above line is executed as early as possible. But this is not a big deal because at any time particular parameters can be defined per particular de-/serialization:

```raku
use LibXML::Config :types;
my $deserialization = Foo.from-xml: $xml, config => { :eager };
$deserialization.to-xml: config => { :severity(STRICT) };
```

The parameters specified this way are used as modifiers for the global config.

Some configuration parameters are rather specific to the processes they regulate and will be described in corresponding sections. Here we'd just mention a few more generic ones.

  * `severity`

    Not every error is fatal. For example, it could be a problem if certain XML element is met twice in the source where we expect only one copy of it. Other times we can safely ignore it. How to react to such errors is controlled by `severity` parameter which can be set to either of `EASY`, `WARN`, `STRICT` values, available via `:types` adverb when `LibXML::Class::Config` is imported. When passed as a key in a profile the value can be a string:

    ```raku
    Foo.from-xml: $xml, config => { :severity<EASY> }
    ```

  * `eager`

    If *True* then lazy operations are disabled (doesn't affect XML sequences).

  * `libxml-config`

    An instance of [`LibXML::Config`](https://libxml-raku.github.io/LibXML-raku/Config) object. By default a new one is created where `:with-cache` is set to *True*.

Serialization And Deserialization
---------------------------------

Let's have a few words on what lies behind serialization and deserialization.

### Serialization

Though there it not much to say about serialization. Whenever the method `to-xml` gets invoked the module traverses the object it's been called upon, picks any serializable attribute and turns it into either `LibXML::Element`, or `LibXML::Attribute`, or `LibXML::Text`. For basic types this is done immediately, for instances of `xml-element` classes we call their `to-xml` method to let these instances serialize themselves.

There are quirks about how namespaces are handled and some other aspects. But otherwise everything is rather straight forward.

### Lazy Deserialization

Before we proceed to deserialization in general, let's talk about laziness first.

A lazy deserialization (lazy operation) is the case where a value is not immediately recovered from an XML element. Instead the operation is postponed until the attribute, corresponding to that element, is actually being read from. The implementation of laziness is covered by [`AttrX::Mooish`](https://modules.raku.org/dist/AttrX::Mooish) as whenever an attribute is considered to be lazy it is the same as applying `is mooish(:lazy)` trait to it. To be more specific, for a `$.foo` it would look like:

```raku
has $.foo is mooish(:lazy<xml-deserialize-attr>, :predicate<xml-has-foo>) ...;
```

Though, when the XML elment name differs from *foo*, like as if we used `is xml-element<fubar>`, then the `predicate` name would use the given *fubar* name for the method:

```raku
has $.foo is mooish(:lazy<xml-deserialize-attr>, :predicate<xml-has-fubar>) ...;
```

**NB** Though, to be admittedf, this naming approach is considered somewhat dubious and may change in future versions of `LibXML::Class`. The point behind the current implementation is that when we consider XML serialization we primarily speak in terms of XML nodes.

### Deserialization

Deserialization is more complex by nature than serialization as it has to deal with bigger range of tasks, including matching and validation of XML nodes to actual attributes, tracking namespaces, providing support for lazy operations, etc. Lots of this tasks are internally done by a special object called *deserialization context*. Each `xml-element` instance creates one for itself and is using it until there is nothing more to deserialize.

Deserialization context is currently considered implementation detail, but some of its methods are likely to be documented and thus proclaimed as public API. Yet, the object itself is accessible via `xml-dctx` method and via `$*LIBXML-CLASS-CTX` dynamic variable for any code invoked within deserialization call stack. For example, it is availble to user provided deserializers.

One of the things to known about the context is that it is responsible for building *constructor profile*, a hash we later turn into named arguments for the constructor (method `new`) of the class we're currently deserializing.

The actual algorithm of deserialization includes the following steps (some small ones are omitted):

  * The deserialization context is being built. The context creates all necessary XML node mapping data structues, namespaces, and a list of unclaimed childrent of the current XML element.

  * For each unclaimed yet child we try to locate the matching descriptor. If succeed then the child is reported as claimed.

  * For a sequence item descriptor the XML child is being placed in a special constructor profile key to be lazily deserialized when accessed, according to the design of XML sequence objects.

  * For an attribute descriptor we find out if lazy operation is allowed. When it is the child node is being sent to the "waiting list". When laziness is not an option then the child is immediately deserializaed into a value which is added to the constructor profile.

  * When all child nodes are processed the context is used to create the `final constructor profile` (or just `final profile`). The hash would include not only immediately deserialized values for user attributes, but also a number of auxiliary fields for attributes of `LibXML::Class::XMLObject` class. The latter's keys are all starting with `xml-`, or `XML-` prefixes, according to the [API Naming](API Naming).

  * Eventually, the being deserialized class is instantiated using `xml-create` method and the final profile.

Among other auxiliary values in the final profile we can find the context itself under `xml-dctx` key. This happens when lazy operations are expected. I.e. we either have sequence items or lazy attributes. This is necessary to let the lazies deserialize at any time in the future. Yet, as soon as every lazy attribute and every sequence item are vivified the context is no more needed and is released for the garbage collector to wipe it out.

#### Unusued Nodes

It is possible that during deserialization some nodes from the source XML elment could remain unclaimed. In an attempt to preserve the original XML source content, `LibXML::Class` collects these unclaimed nodes, serializes them into AST representation using `LibXML::Node` `ast` method, and holds in a positional `xml-unused` attribute. So, one can `$deserialized.xml-unused.map: &process-unused;`.

There is a "side effect" when unclaimed nodes are handled. Depending on configuration `severity` setting the process may produce warnings or even die if the severity is *`STRICT`*.

The unused node are then put back into XML upon serialization of the object. The internal order of the unused nodes is preserved, but not in relation to the actually serialized ones as these would be ordered according to the internal structure of Raku objects involved.

Custom Or Manual De-/Serialization
----------------------------------

**NB** This section is illustrated by [*manual06.raku*](../../../../examples/manual06.raku) code.

It is possible to provide own routines to de-/serialize an attribute using the abovementioned `:serializer` and `:deserializer` arguments of traits. How to deal with them `LibXML::Class` determines based on their signatures.

### Serializer Routine

A serializer routine can take a single or two arguments. When it's single then the serialization process tries to match the currently serialized value against routine's signature ([`cando`](https://docs.raku.org/routine/cando) method) and if succeeds then calls it. The serializer is expected to return a string, to which the valuse has been serialized.

When the signature accepts two arguments then the first one must accept a `LibXML::Element` instance, and the second one must accept the value. This is more complicated, yet more flexible approach where the serializer routine is expected to modify the XML element on its own.

The case of two arguments has one more subcase when it comes to the value argument, not pertinent to the single-argument situation. For positional and associative Raku arguments it is possible that the entire attribute value would be sent out to the serializer for processing. In the [*manual06.raku*](../../../../examples/manual06.raku) file there are two examples where this feature is used. Here is a cut-out from the example:

```raku
multi sub serializer(LibXML::Element:D $elem, Real:D %r) {
    $elem.setAttribute:
        'ratios', %r.sort.map({ .key ~ ":" ~ (.value * 100) ~ "%;" }).join
}

class Record is xml-element<record> {
    has Real:D %.ratio is xml-element(:&serializer);
}
```

Have you noticed the `multi` statement? This is because when there is such necessity a multi-dispatch routine can be used to handle various cases of serialization. BTW, this applies to deserialization routine too.

The two-argument case of serializer doesn't actually make sense for Raku attributes marked with `xml-attribute` and `xml-text` traits. Trying to use such serializer with them will result in the module silently ignoring the routine.

### Deserializer Routine

Deserializer routine signature is considered too when the decision of using it is being made. Since there is no value to operate with (it is about to be produced yet!) all deserializers would have just one positional parameter. But it is still depends on the parameter type what argument the deserializer would be supplied with. I.e. if the parameter is of an `LibXML::Node` type then an XML node would be passed in if available. Otherwise a string with value representation would be the only routine argument.

Apparently, deserializer must return a value for the attribute.

### Common Notes On De-/Serializing

It is to be remembered that `LibXML::Class` doesn't produce an error if no serializer signature matches. Instead, if provided serializer cannot be used then we fall back to the standrd means. This behaviour could become handy when, say, we know that an instance of a subclass could end up in our attribute and special care would need to be taken of it then. Otherwise the standard approach would work well enough for us and there is no need to be explicit about it.

Same rule apply to deserializer: no error if no candidate found.

There are good chances that sometimes inability to de-/serialize something is becomes apparent at run time. At this point user code may decide that it'd be better to give up and let `LibXML::Class` do it. It is possible with an exported `xml-I-cant` routine:

```raku
sub my-serializer(Foo:D $value) {
    if $value.has-attribute {
        xml-I-cant
    }
    $value.serialize-itself;
}
```

There is a test for it in [*t/060-manual-de-serializer.rakutest*](../../../../t/t/060-manual-de-serializer.rakutest).

Implicit XMLization
-------------------

Look into [*manual05.raku*](../../../../examples/manual05.raku). There you'd find a very simple case where an `xml-element` class has an attribute of another class. That other class is not an `xml-element` and, yet, the example works and does what's expected! Well, at least it meets author's expectations.

The "magic" behind the scenes is rahter simple. Whenever `LibXML::Class` encounters a class which is neither basic nor an `xml-element` it tries to implicitly turn the class into a `xml-element`-like one. The process is called "implicit XMLization" and it does the following:

  * simulates application of `xml-element` trait to the original class; this results in a new class type object

  * set the resulting `xml-element` copy to implicit mode

  * turns off lazy operations for it

  * caches the resulting class for re-use

Serialization is using the XMLized class by creating an instance of it which is a full copy of the original object to be serialized using the method `clone-from`. The copy does all the serialization work.

Deserialization does almost the same except that the XMLized class when is done with deserialization creates not an instance of self but an instance of the original class.

All this allows us to always have an instance of the original class in attribute. On the other hand, in, say, `has Foo $.foo;` case even if we serialize an instance of `FooChild` class which is a subclass of `Foo`, deserialization would only try to deserialize into `Foo` itself. But this problem is not about implicit XMLization alone as there is no good way for deserialization to guess the destination class except by checking up with attribute's type.

Containers
----------

There are few details to know about XML containerization.

First of all, when it comes down to namespaces, container element is following what is declared for its Raku attribute.

Container element name would most commonly be provided with `:container<element-name>` argument of `xml-element` trait.

But if the boolean form of the argument is used, i.e. containerization is turned on but no specific name is given, then attribute name is taken. In this case the value element is named based on what the attribute type object would tell us to use. I.e. it could be either a manually provided with `xml-element` trait name, or type object's short name. Apparently, the target type cannot be a basic one then.

XML:any
-------

Sometimes it is not possible to tell what would be a value type beforehand. Like, OK, we know that `has Record $.rec;` tells us that we'd need to de-/serialize `Record`. But what if `Record` is a role? Or, worse, if `$.rec` doesn't have a type constraint whatsoever? There is no big deal when we serialize as we just fetch a value, making sure we know how to handle it – and do handle, eventually, producing an XML element. But deserializing would get into a problem here as there is no legal and safe way to tell that a string maps into `Record`, `Foo`, or, damn it, plain old [`Str`](https://docs.raku.org/type/Str)!

XML:any tries to solve this problem by implementing a mapping between Raku type objects and XML tags, using namespaces. Before going into greater details, let's borrow an example from [`XML::Class`](https://modules.raku.org/dist/XML::Class), where they use SOAP envelope to demonstrate the problem and its solutions:

```xml
<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">
    <Head/>
    <Body>
        <Data xmlns="urn:my-data">
            <Something>some data</Something>
        </Data>
    </Body>
</Envelope>
```

This structure is supposed to map into the following class (traits stripped):

```raku
class Envelope {
    has $.Head;
    has $.Body;
}
```

Clearly, neither `Head` nor `Body` have types associated to them. More importantly, we see that the `<Body>` element of our XML is not a container – it is the attribute. But the value of it is contained by `<Data>`.

What if `<Body>` is a sequence? Then it is possible to see something like the following:

```xml
<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">
    <Head/>
    <Body>
        <Data xmlns="urn:my-data">
            <Something>some data</Something>
        </Data>
        <Data xmlns="http://another.namespace" attr1="for $.attr1">
            <attr2>123.456</attr2>
        </Data>
    </Body>
</Envelope>
```

Now we have at least two `<Data>` elements with different structure *and* different namespaces. This fact we can use because this is what makes XML:any possible.

First of all, we start with defining a map of namespaces, XML element names, and types on our configuration (more detailed illustation can be found in [*manual09.raku*](../../../../examples/manual09.raku)):

```raku
my LibXML::Class::Config $config .= new: ns-map => %( #`{ ns-map declarations go here } );
```

```raku
$root.to-xml: config => {
    ns-map => %( ... ),
};
```

Both of the above cases wind down to calling `set-ns-map` method:

```raku
my LibXML::Class::Config $config .= new;
$config.set-ns-map: #`{ ns-map definitions };
```

The method has many candidates allowing for multiple use scenarios.

The most basic `ns-map` declaration would be a hash of hashes:

```raku
ns-map => {
    "my-ns" => {
        "foo" => Foo,
    }
}
```

With this declaration we tell the module that `<foo namespace="my-ns" .../>`, or `<pfx:foo xmlns:pfx="my-ns" ... />` elements are to be deserialized as `Foo`. Other way around, for:

```raku
class Record is xml-element( :ns( :pfx<my-ns> ) ) {
    has $.attr is xml-element( :ns ); # The attribute is forced to use namespaces of its declarant class
}
```

whenever the value in `$.attr` happens to be an instance of `Foo`, the attribute would serialize into something like:

```xml
<pfx:attr><pfx:foo /></pfx:attr>
```

Hopefully, this example is understandable, even though namespaces are to be discussed later. In the meantime it worth pointing out at the fact that their use allows us to distinguis even same-named elements if they belong to into different namespaces. If we get back to the SOAP envelope example, having two `Data` elements is as simple as having this `ns-map`:

```raku
ns-map => {
    "urn:my-data" => {
        :Data(MyData),
    },
    "http://another.namespace" => {
        :Data(AnotherData),
    }
}
```

Note that `ns-map` is a "globalish" thing, i.e. it's scope is the same as the scope of configuraiton class which has it. It means that the same mapping would likely to be used for different attributes in different type objects. If this is a problem then best solution for it would be to type-constraint an attribute. My guess would be that in the most typical situation allowed types for an XML:any attribute would share some common property, like a role they consume, or a class they inherit from:

```raku
role EnvData { }
class EnvData1 does EnvData { }
class EnvData2 does EnvData { }

$config.set-ns-map:
    "ns1" => { :Data(EnvData1) },
    "ns2" => { :Data(EnvData2) };

class Envelope is xml-element {
    has EnvData $.Data is xml-element( :any );
}
```

This is, basically, all about XML:any attributes. There is more information about XML sequence items, but it fits the [XML Sequence Objects](XML Sequence Objects) section better.

### `ns-map` Variations

Declaring `ns-map` as a hash is the most basic but also the most limited way. There are shortcuts possible.

For example, an `xml-element` class can be used as-is since we can pull out all necessary information directly out of it. This works with a [`List`](https://docs.raku.org/type/List) representation of `ns-map`:

```raku
class Record is xml-element(<rec>, :ns( 'my-ns' )) { ... }

my LibXML::Class::Config $config .= new: ns-map => ( Record, "other-ns" => {...} );
```

This is, roughly, equivalent to:

```raku
my LibXML::Class::Config $config .= new: ns-map => { "my-ns" => {'rec' => Record}, "other-ns" => {...} };
```

Sometimes we don't care about what namespace a type object declares and all we want is its XML name. Then a namespace can be declared with a list as its value:

```raku
my LibXML::Class::Config $config .= new: ns-map => ( "other-ns" => (Record, "foo" => Foo) );
```

Some of possible variants are demoed in [*manual09.raku*](../../../../examples/manual09.raku).

XML Sequence Objects
--------------------

At the first glance, XML sequence (later in this section the term would often be shortened to just *sequence*) in the [Some Terminology](Some Terminology) section of this manual looks a lot like a containerized [`Array`](https://docs.raku.org/type/Array) with items of different types. Though it isn't. The key differences are:

  * A sequence natively supports items of different types. One can do it for arrays too with help of [`subset`](https://docs.raku.org/language/typesystem#subset), but it would be a hassle. As it would be shown below, declaring class a sequence is more readable.

  * Sequences are always lazy. Just always, no exceptions, no respect to [`LibXML::Class::Config`](Config.md) `eager` flag.

    One could point out that an array attribute could be marked lazy too. There is a catch though: the array is anyway deserialized as a whole, all items at once. A sequence is lazy on per-item basis. I.e. when there is something like `@.list[42]` the entire `@.list` will be vivified, even if it consists of hunderds of items. Contrary, for a sequence `$.list[42]` would mean that the sequence itself would be vivified first (unless it's not done yet), then the item at position 42 is deserialized and returned for our use. Referencing, say, `$.list[12]` later would only result in deserialization of the 12th position as the sequence object is already there.

    This makes sequences great when dealing with *long* lists of values.

  * What an array is most definitely not capable of is mainaining individual de-/serialization properties on per-type basis. For example, if our sequence type object is configured for items of `Foo` and `Bar` type then for each one we can individually configure namespace parameters, serializer, and deserializer.

  * XML sequences can contain non-item elements too. From the Raku language point of view it means they can have serializable attributes:

    ```xml
    <my-seq>
      <rec1>val1</rec1>
      <rec2 value="foo1" />
      <rec2 value="foo2" />
      <foo value="this comes from $.foo attribute"/>
      <counter>42</counter> <!-- has Int $.counter; -->
    </my-seq>
    ```

  * A sequence type can be a composition of other sequence and non-sequence types. For a type to start behaving as a sequential it is enough for just any of its roles or parents to be one.

### Declaring An XML Sequence

Sequences are declared with help of `:sequence` named argument of `xml-element` type object declaration:

```raku
class References is xml-element( :sequence( :idx(Int:D), :ref(Str:D, :attr<title>) ) ) {
    has Str:D $.title is required;
}
```

Here we define a sequence which can consist of integer or string items. Following is an example of using the sequence from [*manual07.raku*](../../../../examples/manual07.raku):

```raku
my $refs = References.new: :title('An Article');
$refs.push: 123456;
$refs.push: "3rd Party Article";
$refs.push: "Another Article";
$refs.push: 987654;
```

It serializes into:

```xml
<References title="An Article">
  <idx>123456</idx>
  <ref title="3rd Party Article"/>
  <ref title="Another Article"/>
  <idx>987654</idx>
</References>
```

The example in [*manual08.raku*](../../../../examples/manual08.raku) demonstrates that using an `xml-element` class as a sequence item type is even easier as it would normally has all we need to deserialize it:

```raku
class Ref is xml-element<ref> {...}
class Index is xml-element('index', :sequence( Ref, :idx(Int:D) )) {...}
```

### Item Parameters

In a way, a sequence item shares some properties with attributes. After all, attributes can be serialized into elements, same as items do. Internally both are handled with help of *descriptors* that inherit from the same descriptor parent class. That makes it possible for items to have certain parameters adjusted using named arguments:

```raku
class Index
    is xml-element(
        :sequence(
            ( Ref, :derive ),
            :idx( Int:D, :ns('some-ns') ),
            :meta( Str:D, :attr<data> ) ))
{...}
```

The following arguments are supported:

  * `:attr(Str:D)` or `:value-attr(Str:D)`

    These are aliases of the same thing: name of XML attribute to contain basic type value.

  * `:namespace(...)`, `:ns(...)`

    Again, just two aliases. Define item namespace profile.

  * `:derive`

    Turns on or off attribute namespace deriving mode. See the section [Namespaces](#Namespaces).

  * `:&serializer`, `:&deserializer`

    User provided serialization/deserialization.

### XML:any Items

Normally it doesn't make sense to use `:any` argument when declaring an `xml-element` type object. Unless for XML sequences. Marking one as XML:any allows to use `ns-map` for sequence items.

There are two screnarios where XML:any helps with item de-/serialization ([*manual10.raku*](../../../../examples/manual10.raku)).

  * Basic type

    Since basic types doesn't have names binding them to an XML element name could be done with the help of `ns-map`.

  * Role-constrained items

    Even though it is possible to declare an item as `:elem(SomeRole)` the declaration barely makes much sense for deserialization because there is no way to know what class to deserialize an `<elem ...>` into. As a best guess we can pun the `SomeRole` role, but the resulting class is sufficiently likely to be useless. But XML:any could be very handy here.

XML:any item elements are not getting wrapped into any kind of container, except for the sequence tag itself which is a container on its own, as a matter of fact.

Otherwise they way XML:any works for items is no different what how it does for attributes.

### Is Item Deserialized?

Since the sequences are always lazy it may be needed to know if an item has been deserialized alredy or not. In a way, this could be done using the `EXISTS-POS` method on a sequence, or `:exists` adverb on `[]`-operator. But there are considerations which make this approach not very reliable.

First, an item could be deserialized but later removed with the `DELETE-POS` method or the `:delete` adverb. Second, a new item could be pushed onto the sequence which hasn't came from deserialization.

Therefore, in addition to the methods, standard for [`Array`](https://docs.raku.org/type/Array), XML sequences introduce an additional one: `HAS-POS`. The method is also backed by the `:has` adverb on `[]`:

```raku
$xml-sequence.HAS-POS(1);
$xml-sequence[1]:has;
$xml-sequence[1]:!has;
```

The method would report an item as deserialized even if it's been later deleted and `EXISTS-POS` is reporting *False*.

Namespaces
----------

`LibXML::Class` tries to follow XML rules whenever possible when it comes to namespaces. However, Raku is not XML, apparently, and what is natural to the latter may not be as natural for the former. To make it all easier the module tries to mainain reasonable defaults while allowing to do fine-tuning when necessary.

Here is the basic rules of namespacing in `LibXML::Class`:

  * An object namespace information may have a prefix (the *"pfx"* in `<pfx:foo/>`), a default namespace (*"default"* in `<foo xml-ns="default" /`), and prefix definition registry where prefixes are mapped into respective namespaces.

  * For every object namespace is defined by its prefix if set; otherwise the default namespace is used.

  * Raku attribute declaration is the primary authority for any namespace information. If the attruibute declaration doesn't provide any then class declaration is used if attribute's type is an `xml-element` type object.

  * If an object doesn't get its namespace neither for the attribute nor from its class then the default namespace of attribute's declarator is used.

These basics can be seen in action in [*manual11.raku*](../../../../examples/manual11.raku). Pay attention to how overriding the default namespace with `xml-default-ns` profile key affects the result where elements with no explicit namespaces still are bound to the default, whereas `$.rec` sticks to what is declared for `Record`.

It is expected that this behavior would cover most cases of de-/serializing with namespaces.

### Declaring Namespaces With `:namespace`/`:ns` Argument

The common argument to declare namespace information is `:namespace`, or its shorter alias `:ns`. The arguments itself can take arguments but can also be used as a flag with attributes or sequence items. Let's start with the latter.

  * When used as plain `:namespace` (`:ns`) the argument signals that the element must take both the prefix and the default from its declarant type object. Make sure you get it right: not from object, not from `xml-element` class, but from direct declarant type object! For example:

    ```raku
    role Recordish is xml-element( :ns<role-default> ) {
        has Str $.foo is xml-element( :namespace );
    }
    class Record is xml-element( :ns<class-default> ) does Recordish {
        has Int $.count is xml-element;
    }
    ```

    `$.foo` will always have no prefix and the default namespace set to *"role-default"*. Whereas `$.count` would continue to use the default, calculated for a `Record` instance.

    See [*manual12.raku*](../../../../examples/manual12.raku).

  * When used as plain negation `:!namespace` (`:!ns`) the argument would make its attribute or sequence item to force the default namespace rules, no matter what `:impose-ns` or `:derive` are telling us. These two have not been discussed yet, but [*manual13.raku*](../../../../examples/manual13.raku) should be pretty much clear for understanding.

  * `:namespace` can take arguments and in this case it expects:

      * One or none default namespace string

      * One or none default namespace prefix as a *True*-value [`Pair`](https://docs.raku.org/type/Pair)

      * A list of [`Str`](https://docs.raku.org/type/Str)-value pairs where keys are namespace prefixes, and the values are namespaces

    For example:

    ```raku
    :ns("default-ns", :pfx, :pfx('http://prefix.namespace', :foo('http://foo.namespace')))
    ```

    This declaration contains one default namespace *"default-ns"*, one default namespace prefix *pfx*, and definitions for prefixes *pfx*, and *foo*.

    *Note* that `LibXML::Class` does its best to preserve the order in which prefix declarations are encountered. It means that whatever entity, which used the above `:ns` declaration would have *xmlns:pfx*, and *xmlns:foo* attributes to appear in exactly this order when serialized into the final XML.

### Defined And Undefined Namespace

A namespace is considered *defined* for an entity if any of the default or prefix is set to a concrete value. For the default namespace it means that even when it is *no namespace* value, which is an empty string *""*, we consider it as defined.

### Namespaces Propagation

Default namespace and prefix definitions are propagaded from the entity, where they are declarated, downstream to the child `xml-element` entitiies. This rule doesn't apply to the default prefix. In [*manual14.raku*](../../../../examples/manual14.raku) the propagation principle is demonstrated by declarations of class `Record` and attribute `@.info` of `Meta` where both are using prefix *foo* as their default even though it is declared for `Root`.

The example is also good to see how not declaring the default namespace results in the top-level one to be used, even when a parent element is explicitly prefixed. While it might not be really apparent at the first glance, but this is to follow XML principles.

### Imposing Namespaces

Sometimes it makes sense for type object's default namespace and prefix to be used by all serializable attributes, except for `xml-text` one, of course. Apparently, one way to do it is to use boolean `:namespace` with each one, but that could be too tedious for a big number of attributes. Instead, with `:impose-ns` argument of `xml-element` trait, this could be achieved "in a single click":

```raku
role Itemish is xml-element(:impose-ns, :ns(:pfx)) {
    has Str $.attr1 is xml-element;
    has Int $.attr2 is xml-attribute;
}
class Item is xml-element(:ns("my-ns", :pfx<pfx-ns>)) does Itemish {
    has Num $.attr3 is xml-element;
}
```

This snippet is done this way to illustrate how a role can enforce its defaults while a class consuming the role would still be using its own defaults.

Imposition only applies to entities with undefined namespace.

### Deriving Namespace Defaults

When we say that an entity is *deriving* its namespace defaults it means that it takes them from its parent XML element. In other words, if we want something to *derive* then we want it to stick to the same namespace as its parent XML element.

Have you noticed the doubling of 'parent XML element'? This is because what is really takes place when defaults are computed for an attribute or sequence item, no matter wether we serialize or deserialize. In either case, when we come down to processing the entity it means that the parent element of it has been validated and its namespacing is fully established.

Derivation can be triggerred on per entity with help of `:derive` keyword, or disabled using negated version `:!derive`.

To have it as the default globally or per-document one can use corresponding setting on [`LibXML::Config`](https://modules.raku.org/dist/LibXML::Config):

```raku
LibXML::Config.global(:derive);
```

or per document:

```raku
class Root is xml-element(...) {...}
my $root = Root.new(...);
$root.to-xml( :config{:derive} );
```

Sometimes it makes sense to have derivation default on or off for only XML elements or attributes. This is done by specifying corresponding named argument with `:derive`:

```raku
$root.to-xml( :config{ :derive(:attribute) } );
$root.to-xml( :config{ :derive(:element) } );
```

The case of individual default is well covered by [*200-pml-parser.rakutest*](../../../../t/200-pml-parser.rakutest), where attributes of the source XML are all prefix-less whereas elements are prefixed. The test also makes a great explanation as to why derivation exists as such. Even though the source XML is using *xsd* prefix, but generally speaking, this choice is somewhat arbitrary and any other prefix can be used. What is not arbitrary is that the prefix is persistent and is shared among parent and children elements.

[*manual15.raku*](../../../../examples/manual15.raku) contains simpler but made up example of deriving. It also has an example of what happens when we deserialize without `:derive` a structure that's been serialized with this setting. In few words, we end up with unused elements and get warned about it (or worse, depending on config's `severity` parameter).

Derivation defaults only for entities with undefined namespace.

XML Element Based Search
------------------------

One of the features of [`LibXML`](https://modules.raku.org/dist/LibXML) module that quickly captures ones attention from the start is [XPath based search](https://github.com/libxml-raku/LibXML-raku/blob/0.10.3/docs/Node.md#method-findnodes) for XML nodes within document. Apparently, it wouldn't work for deserialized... But you guessed it already: it actually does! Because navigating a big datastructure, looking for Raku representation of a particular XML node is not easy if possible at all.

The search is implemented for both `xml-element` type objects and [`LibXML::Class::Document`](Document.md). Though the method on the type objects is following API naming guidelines and is named `xml-findnodes`, whereas on the document, which is a `LibXML::Class` thing on its own, it doesn't have the prefix and is simply named `findnodes`. Otherwise both are eventually end up calling document's `find-deserialization` method.

Searching for deserialization is, in a way, rather simple process of mapping XML node unique key, provided by the `unique-key` method of `LibXML::Node`, into a Raku object produced from that node. Since `LibXML::Node` `findnodes` method returns an iterable, `LibXML::Class` searches would come up with a [`Seq`](https://docs.raku.org/type/Seq) of found deserializations.

Note, please, how the term 'Raku object' adove is used without any reference to `LibXML::Class`. This is because deserialization of a node might result an anything, ranging from basic type value to whatever user-provided deserializer returned.

Another important note to be made is that the permanent reference to 'deserialization' is not accidental and it means that search only works for `xml-element`-instances produced from some kind of XML source.

So far so good, but let's get back to that infamous "in a way" saying above. Not even to mention that deserializations are often lazy by default because this is not your problem and `LibXML::Class` is seemingly succeeds in solving it for you. But there are unapparent surprises like XML contaners (`:container` declaration), arrays, sequences, XML attributes...

Luckily, there is one simple rule to remember about all of them: if an XML node has been used to produces a deserialization then search would return that deserialized value. Most simple example would be an XML container element mapping into the attribute value, for which it was declared. A container's child element would map either into the same attribute, or into it's respective array element, etc.

Another case would be a text node. Since there could only be single `xml-text` attribute on a class, even if an XML element contains multiple `#text` they all would result in the same attribute value.

### Disabling Or Tuning The Search Feature

If you are not interested in searching and would like to spare some memory instead then consider disabling `deserialization-registry` on configuration object:

```raku
LibXML::Config.global( :disable-registry );
# ... or ...
$root.from-xml: ..., :config{ :disable-registry };
```

Another potentially memory-hungry feature is the *global index* of deserializations held by the document instance. Even though it only contains `xml-element` objects, a big XML structure might end up having too many of them. The global index is actually just a cache to speed up search. For this reason it can be safely disabled. In this case the search would fall back to tree traversal approach, starting from the document root and going down its attributes. Even though it is not as fast as a cache lookup, it's still good enough and takes less memory:

```raku
LibXML::Config.global( :!global-index );
# ... or ...
$root.from-xml: ..., :config{ :!global-index };
```

### Caveats

  * A search is always resulting in a `Seq`, even if it is done for a single XML node. Moreover, there are chances that the `Seq` would consists of more than a single object! This is because a deserialization can be, for example, cloned. For a basic time cloning the value do nothing, but an `xml-element` takes care of registering itself as a candidate.

  * Be careful when searching for an unused element or its child nodes of any kind as this is an error situation.

CONTRIBUTING
============

Please, submit bugs or pull requests to https://github.com/vrurg/raku-LibXML-Class. Any help would be appreciated!

SEE ALSO
========

  * [*README*](../../../../README.md)

  * [`LibXML::Class`](../Class.md)

  * [`LibXML::Class::Config`](Config.md)

  * [`LibXML::Class::Document`](Document.md)

COPYRIGHT
=========

(c) 2023, Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the [*LICENSE*](../../../../LICENSE) file in this distribution.

