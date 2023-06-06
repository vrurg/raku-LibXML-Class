`LibXML::Class` Manual
======================

DISCLAIMERS
-----------

  * [`LibXML::Class`](docs/md/LibXML/Class.md) is not capable of handling all possible variations of XML files. Despite all the efforts taken to cover as many possible cases as possible, mapping of Raku objects into XML is and likely will remain its primary purpose.

  * Due to its extensive nature, this manual is created in mainly write-only mode, no proof-reading and other time-consuming luxuries. My deepest apologies for all the errors, but the priorities don't give me many choices.

  * Some concepts here may resemble what is familiar to you by [`XML::Class`](https://modules.raku.org/dist/XML::Class) implementation. This is because up to some extent `LibXML::Class` has been inspired by it. Yet, the differences are way too significant, so don't let yourself fall into the trap of "Ah, I already know what's this is about!"

Kick-start
----------

The fastest way to start using `LibXML::Class` is to apply a bare `xml-element` trait to a class or role:

    class Record is xml-elemnt {
        has Int:D $.id is required;
        has Str:D $.comment is required;
        has Num $.amount;
    }

And this is it. Now, anytime an instance `$record` of `Record` can be serialized into `LibXML::Document` by calling `to-xml` method on it:

    say $record.to-xml;

In a slightly more complex case an attribute of a class can store an instance of another `xml-element` class:

    class Root {
        has Record:D $.record is required;
    }

See `manual1.raku` in *examples* directory.

### Roles

Not only classes bu roles can be declared as `xml-element` too. Depending on how a role is used the effect could differ.

Consuming an `xml-element` role by a plain class turns it into a serializable explicit (see more on implicit/explicit declarations below) class.

Consuming such role by a `xml-element` class would simply extend it with role's functionality while allowing the role to maintain control over some serialization aspects like, for example, namespaces.

See *explamples/manual2.raku* and *examples/manual3.raku*.

API Naming
----------

The way [`LibXML::Class`](../Class.md) works in the above example is by adding a role to the type object `xml-element` is used with. The role, in turn, adds a parent class `LibXML::Class::XMLObject`. Normally these implementation details must not bother you, but they worth mentioning from the point of view that there is a lot of extra methods become available on the instances of `xml-element` classes.

In order to minimize possible conflicts or side effects, it's been taken into account that the XML standard prohibits node names starting with `xml` prefix. Therefore almost every public or private method or attribute names, declared by `LibXML::Class` classes or roles, are starting with `xml-`. Moreover, in some cases `LibXML::Class` ignores all user attributes if they start with the same `xml-` prefix.

There is only two exceptions: methods `to-xml` and `from-xml`, but these are rather part of more common convention within Raku ecosystem. Besides, it'd be ugly to have a call like `$obj.xml-to`.

Some Terminology
----------------

  * **Basic types**

    As very rough first approach we can say that for [`LibXML::Class`](../Class.md) a basic type is the one which trivially stringifies and into which we can trivially coerce from a string. These include [`Numeric`](https://docs.raku.org/type/Numeric), [`Stringy`](https://docs.raku.org/type/Stringy), [`Dateish`](https://docs.raku.org/type/Dateish), and [`Enumeration`](https://docs.raku.org/type/Enumeration) consuming types; [`Bool`](https://docs.raku.org/type/Bool), [`Mu`](https://docs.raku.org/type/Mu), and [`Any`](https://docs.raku.org/type/Any).

    Depending on the context, non-basic types could be called *'complex'*, *'user defined'*, etc.

  * **XMLized** type object

    A type object which can be XML de-/serialized. In technical terms of [`LibXML::Class`](../Class.md) this means it consumes `LibXML::Class::XMLRepresentation` role. This term bears slightly different meaning to that of *'`xml-element` type object'* because the latter is only about classes of roles with `xml-element` trait applied, whereas an XMLization also about implicitly converted classes like in the abovementioned case of consuming an `xml-element` role.

  * **XML sequence**, **XML sequential**

    This term has its roots in *.xsd* schemas of [ECMA-376](https://www.ecma-international.org/publications-and-standards/standards/ecma-376) standard. A sequential XML element is a [`Positional`](https://docs.raku.org/type/Positional) (in terms of Raku) container. For example:

        <my-seq>
          <rec1>val1</rec1>
          <rec2 value="foo1" />
          <rec2 value="foo2" />
          <rec1>val2</rec1>
          <rec1>val1</rec1>
        </my-seq>

  * **Value element**

    An XML element representing a value. The most typical cases are `<amount val="42.12"/>` and `<amount>42.12</amount>`. In more complex cases when the value, represented by the element, is not of a basic type the element may has more attributes and child elements.

  * **XML container**, **XML containerization**

    An XML element wrapping around value elemnt or series of elements. For example:

        <container>
           <val-element>42</val-element>
        </container>

    A container is serialized from single argument and, correspondigly, deserialize into single argument. I.e. the above example would end up as value *42* in `$.val-element`.

  * **Descriptors**

    Whenever we declare an `xml-element` type object we need to tell the module what subsidiary entities of the type object are de-/serializable too. There are currently two kinds of them: Raku attributes and items of an XML sequence representations. For every such entity a descriptor gets created which contains all information necessary to deal with the object.

Exported Traits
---------------

[`LibXML::Class`](../Class.md) exports just three traits to mark Raku objects as XML-serializable:

  * The aforementioned `xml-element` to produce an XML element, applicable to type objects and attributes

  * `xml-attribute`, which can only be used with class/role attributes, to result in an XML element attribute

  * `xml-text` is also a Raku attribute-only trait which can only be used once per object

For example:

    class Record is xml-element {
        has Str $.attr is xml-attribute;
        has Str $.content is xml-text;
    }

    say Record.new(:attr<something>, :content("line1\nline2")).to-xml;
    # <?xml version="1.0" encoding="UTF-8"?>
    # <Record attr="something">line1
    # line2</Record>

Both `xml-element` and `xml-attribute` share similar signatures: `<trait>(Str:D $name?, *%named)` – where `$name` is element/attribute name to be used. If omitted then see the section [Naming Conventions](Naming Conventions) below. The allowed named arguments vary depending on the context and object a trait is applied to.

`xml-text` doesn't take any positional argument but also shares a few named ones with the other two traits.

### XML Nodes Naming Conventions

The order in which a XML node gets its name is defined by the rules in this section. The rules differ for each of `xml-attribute` and `xml-element` traits.

For `xml-attribute` everything is simple:

  * if an explicit name is provided as trait only positional this name is used

  * otherwise attribute base name (with no sigil and twigil) is taken

Things are somewhat less simple for `xml-element`. First of all, looking ahead, let us mention that when serializaing an attribute as XML element it's possible to specifiy that we want it to be wrapped into a special tag we call 'container'. [Containerization](#Containers) will have its own section down below in this manual, so for now we just need to know about it.

  * if an explicit name is provided as trait's positional argument then it is used

  * otherwise attribute's base name without sigil and twigil is used

  * if attribute is not containerized or container has an explicit name then we're done

  * otherwise if container has no name (i.e. the named argument is boolean `:container`) then

    * the name developed at the first two steps is used for the container element

    * if attribute's value type is an `xml-element` then it's name is taken

    * if the type is not an `xml-element` then its short name (`.^shortname`) is used

There is a case if sequential `xml-element` classes where child items of corresponding XML element are to be somehow named too. But they basically follow the same rules except they cannot be containerized.

### Type Object `xml-element` Named Arguments

When `xml-element` is used with a class or a role the following named arguments can be used:

  * `:implicit`

    A boolean specifying if typeobject arguments are to be implicitly serialized. Can be negated. See the section [Implicit Or Explicit](Implicit Or Explicit).

  * `:lazy`

    A boolean, turn on or off lazy deserialization.

  * `:ns`

    This argument is in charge of XML namespaces. See the section [Namespaces](https://modules.raku.org/dist/Namespaces).

  * `:impose-ns`

    If this boolean is *True* then any attribute not having its own `:ns` argument would use namespaces of its parent typeobject serialization. See the section [Namespaces](https://modules.raku.org/dist/Namespaces).

  * `:sequence`

    This argument makes the type object serializing into an XML sequence. See more details in [XML Sequence Objects](XML Sequence Objects).

  * `:any`

    This boolen only makes sense when used with `:sequence`. It allows very flexible way of defining and determening sequence items value types.

When `xml-element` is used with a class more named arguments become available:

  * `:derive`

    Turns on or off attribute namespace deriving mode. See the section [Namespaces](https://modules.raku.org/dist/Namespaces).

  * `:severity`

    Only used when the class is used as the root element of XML document. Sets severity mode of [`LibXML::Class::Config`](Config.md) configuration.

### Attribute Traits Named Arguments

All three attribute traits: `xml-element`, `xml-attribute`, and `xml-text` – share a few named arguments:

  * `:lazy`

    Enforce lazy deserialization for the attribute.

  * `:&serializer`, `:&deserializer`

    User provided serialization/deserialization.

The following arguments are shared by `xml-element` and `xml-attribute`:

  * `:ns(...)`

    This argument defines what namespaces are to used with XML node serialized from the attribute. See the [Namespacing](https://modules.raku.org/dist/Namespacing) section.

  * `:derive`

    Boolean that controls namespace deriving for the attribute.

The following arguments are specific to `xml-element`:

  * `:value-attr(Str:D)`/`:attr(Str:D)`

    Normally a basic type would serialize into an XML element with `#text` node representing its value. With this argument an XML attribute would be used instead of a `#text`. For example, with `:value-attr<val>` `$.bar` for an example above would become `<bar val="bar value"/>`.

  * `:any`

    Marks attribute as *XML:any*, making it possible to deserialize corresponding element into various Raku types. See the [XML:any](XML:any) section.

  * `:container(Str:D|Bool:D)`

    Marks the attribute as XML-containerized. If given a string value like `:container<container>` then it defines container XML element name at the same time. See the [Containers](#Containers) section.

Implicit Or Explicit Declarations
---------------------------------

When `xml-element` trait is applied to a type object by default it tries to use *implicit* mode meaning that all attributes of the object are marked as serializable. A typical example of implicit class is the example in the [Kick-start](Kick-start) section above.

Contrary, with `:!implicit` argument the object is set to explicit mode where only explicitly marked attributes are serializable. For example:

    class Foo is xml-element(:!implicit) {
        has Int $.foo;
        has Str $.bar;
    }

Neither `$.foo` nor `$.bar` would not be serialized into XML. But:

    class Foo is xml-element(:!implicit) {
        has Int $.foo;
        has Str $.bar is xml-element;
    }

Here we would still miss the `$.foo` attribute, though a value in `$.bar` would end up in an XML representation of `Foo` (if set to something defined, of course).

Normally, there is no need to use `:!implicit` as every time we mark an attribute with any of `xml-element`, `xml-attribute`, or `xml-text` the type object is automatically gets its implicitness turned off. This is also what happens when an `xml-element` role is consumed by a non-`xml-element` class, as it was mentioned in [Roles](https://modules.raku.org/dist/Roles).

There is a reson to use `:implicit` explicitly (no pun meant!) when declaring a type object. It makes sense if one wants all attributes to be auto-serialized except for few they want to give some special properties to:

    class Foo is xml-element(:implicit) {
        has Int $.foo;
        has Str $.bar is xml-element;
    }

In this example both attributes would get serialized if set. But `$.foo` would become an XML attribute, and `$.bar` would be an XML element (see *examples/manual4.raku*):

    <?xml version="1.0" encoding="UTF-8"?>
    <Foo foo="42">
      <bar>textual value</bar>
    </Foo>

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

    LibXML::Class::Config.global(:eager);

The singleton can be initialized just once. Due to methods `to-xml` and `from-xml` implicitly vivifying the global config it's better to make sure that the above line is executed as early as possible. But this is not a big deal because at any time particular parameters can be defined per particular de-/serialization:

    use LibXML::Config :types;
    my $deserialization = Foo.from-xml: $xml, config => { :eager };
    $deserialization.to-xml: config => { :severity(STRICT) };

The parameters specified this way are used as modifiers for the global config.

Some configuration parameters are rather specific to the processes they regulate and will be described in corresponding sections. Here we'd just mention a few more generic ones.

  * `severity`

    Not every error is fatal. For example, it could be a problem if certain XML element is met twice in the source where we expect only one copy of it. Other times we can safely ignore it. How to react to such errors is controlled by `severity` parameter which can be set to either of `EASY`, `WARN`, `STRICT` values, available via `:types` adverb when `LibXML::Class::Config` is imported. When passed as a key in a profile the value can be a string:

        Foo.from-xml: $xml, config => { :severity<EASY> }

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

    has $.foo is mooish(:lazy<xml-deserialize-attr>, :predicate<xml-has-foo>) ...;

Though, when the XML elment name differs from *foo*, like as if we used `is xml-element<fubar>`, then the `predicate` name would use the given *fubar* name for the method:

    has $.foo is mooish(:lazy<xml-deserialize-attr>, :predicate<xml-has-fubar>) ...;

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

Custom Or Manual De-/Serialization
----------------------------------

**NB** This section is illustrated by [examples/manual6.raku](examples/manual6.raku) code.

It is possible to provide own routines to de-/serialize an attribute using the abovementioned `:serializer` and `:deserializer` arguments of traits. How to deal with them `LibXML::Class` determines based on their signatures.

### Serializer Routine

A serializer routine can take a single or two arguments. When it's single then the serialization process tries to match the currently serialized value against routine's signature ([`cando`](https://docs.raku.org/routine/cando) method) and if succeeds then calls it. The serializer is expected to return a string, to which the valuse has been serialized.

When the signature accepts two arguments then the first one must accept a `LibXML::Element` instance, and the second one must accept the value. This is more complicated, yet more flexible approach where the serializer routine is expected to modify the XML element on its own.

The case of two arguments has one more subcase when it comes to the value argument, not pertinent to the single-argument situation. For positional and associative Raku arguments it is possible that the entire attribute value would be sent out to the serializer for processing. In the [examples/manual6.raku](examples/manual6.raku) file there are two examples where this feature is used. Here is a cut-out from the example:

    multi sub serializer(LibXML::Element:D $elem, Real:D %r) {
        $elem.setAttribute:
            'ratios', %r.sort.map({ .key ~ ":" ~ (.value * 100) ~ "%;" }).join
    }

    class Record is xml-element<record> {
        has Real:D %.ratio is xml-element(:&serializer);
    }

Have you noticed the `multi` statement? This is because when there is such necessity a multi-dispatch routine can be used to handle various cases of serialization. BTW, this applies to deserialization routine too.

The two-argument case of serializer doesn't actually make sense for Raku attributes marked with `xml-attribute` and `xml-text` traits. Trying to use such serializer with them will result in the module silently ignoring the routine.

### Deserializer Routine

Deserializer routine signature is considered too when the decision of using it is being made. Since there is no value to operate with (it is about to be produced yet!) all deserializers would have just one positional parameter. But it is still depends on the parameter type what argument the deserializer would be supplied with. I.e. if the parameter is of an `LibXML::Node` type then an XML node would be passed in if available. Otherwise a string with value representation would be the only routine argument.

Apparently, deserializer must return a value for the attribute.

### Common Notes On De-/Serializing

It is to be remembered that `LibXML::Class` doesn't produce an error if no serializer matches. Instead, if provided serializer cannot be used then we fall back to the standrd means. This behaviour could become handy when, say, we know that an instance of a subclass could end up in our attribute and special care would need to be taken of it. Otherwise the standard approach would work well enough for us and there is no need to be explicit about it.

Same rule apply to deserializer: no error if no candidate found.

Implicit XMLization
-------------------

Look into *examples/manual5.raku*. There you'd find a very simple case where an `xml-element` class has an attribute of another class. That other class is not an `xml-element` and, yet, the example works and does what's expected! Well, at least it meets author's expectations.

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

XML Sequence Objects
--------------------

At the first glance, XML sequence (later in this section the term would often be shortened to just *sequence*) in the [Some Terminology](Some Terminology) section of this manual looks a lot like a containerized [`Array`](https://docs.raku.org/type/Array) with items of different types. Though it isn't. The key differences are:

  * A sequence natively supports items of different types. One can do it for arrays too with help of [`subset`](https://docs.raku.org/language/typesystem#subset), but it would be a hassle. As it would be shown below, declaring class a sequence is more readable.

  * Sequences are always lazy. Just always, no exceptions, no respect to [`LibXML::Class::Config`](Config.md) `eager` flag.

    One could point out that an array attribute could be marked lazy too. There is a catch though: the array is anyway deserialized as a whole, all items at once. A sequence is lazy on per-item basis. I.e. when there is something like `@.list[42]` the entire `@.list` will be vivified, even if it consists of hunderds of items. Contrary, for a sequence `$.list[42]` would mean that the sequence itself would be vivified first (unless it's not done yet), then the item at position 42 is deserialized and returned for our use. Referencing, say, `$.list[12]` later would only result in deserialization of the 12th position as the sequence object is already there.

    This makes sequences great when dealing with *long* lists of values.

  * What an array is most definitely not capable of is mainaining individual de-/serialization properties on per-type basis. For example, if our sequence type object is configured for items of `Foo` and `Bar` type then for each one we can individually configure namespace parameters, serializer, and deserializer.

  * XML sequences can contain non-item elements too. From the Raku language point of view it means they can have serializable attributes:

        <my-seq>
          <rec1>val1</rec1>
          <rec2 value="foo1" />
          <rec2 value="foo2" />
          <foo value="this comes from $.foo attribute"/>
          <counter>42</counter> <!-- has Int $.counter; -->
        </my-seq>

  * A sequence type can be a composition of other sequence and non-sequence types.

Sequences are declared with help of `:sequence` named argument of `xml-element` type object declaration:

    class References is xml-element( :sequence( :idx(Int:D), :ref(Str:D, :attr<title>) ) ) {
        has Str:D $.title is required;
    }

Here we define a sequence which can consist of integer or string items. Here is an example of using the sequence from [examples/manual7.raku](examples/manual7.raku):

    my $refs = References.new: :title('An Article');
    $refs.push: 123456;
    $refs.push: "3rd Party Article";
    $refs.push: "Another Article";
    $refs.push: 987654;

[examples/manual8.raku](examples/manual8.raku)

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the LICENSE file in this distribution.

