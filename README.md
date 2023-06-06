NAME
====

`LibXML::Class` – general purpose XML de-/serialization for Raku

SYNOPSIS
========

Simple Case
-----------

    use LibXML::Class;

    class Record1 is xml-element {
        has Int:D $.id is required;
        has Str $.description;
        has %.meta;
    }

    my $rec = Record1.new(:id(1000), :description("test me"), :meta{ key1 => π, key2 => "some info" });

    say $rec.to-xml.Str(:format);

This would result in:

    <?xml version="1.0" encoding="UTF-8"?>
    <Record1 id="1000" description="test me">
      <meta>
        <key1>3.141592653589793e+00</key1>
        <key2>some info</key2>
      </meta>
    </Record1>

More Complex Case
-----------------

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

`LibXML::Class` implements serialization and deserialization of Raku object into/from XML and, as the name suggests, is based upon fast `LibXML` framework. The module tries to be as simple in use as possible and, yet, provide wide range of features to cover as many use cases as possible. The notable features are:

  * Namespaces support

  * Out of the box hashes and arrays support

  * Implicit or explicit declarations

  * Support for roles and inheritance

  * Lazy deserialization

  * User provided de-/serialization

  * Search for deserialization of a paricular XML node, including XML attributes and `#text` nodes

  * Sequential XML elements (like arrays but lazily deserialized and allowing for different item types)

  * Variative attribute types

  * Preservation of unused XML nodes upon deserialization in order to save the original XML as much as possible

Some of the features were inspired by `XML::Class` module, but they were heavily reconsidered. Others are totally unique to `LibXML::Class`. Of these special attention is to be paid to the search feature. Let's take the [SYNOPSIS](#SYNOPSIS) complex example and add a few more lines right after the '`my $root-copy = Registry.from-xml: $xml.Str;`' line:

    my $root-doc = $root-copy.xml-document;
    my $xml-root = $root-doc.libxml-document.documentElement;
    my $amount-elem = $xml-root[0][1]; # Pick the <amount>42.12</amount> element
    is $root-doc.find-deserializations($amount-elem), (42.12,), "first <amount> element value is 42.12";
    cmp-ok $root-doc.find-deserializations($xml-root[1]).head, '===', $root-copy.record[1],
           "second <record> element deserialization found";

These would add two more test outcomes indicating that the first call to `find-deserializations` finds the value stored in `$.amount` attribute of the first item in `@.record` on the `Registry` class. And the second `find-deserializations` call produces the second record on the array.

DISCLAIMER
==========

[`LibXML::Class`](docs/md/LibXML/Class.md) is not capable of handling all possible variations of XML files. Despite all the efforts taken to cover as many possible cases as possible, mapping of Raku objects into XML is and likely will remain its primary purpose.

SEE ALSO
========

  * To get better accustomed with the kind of lazines used by `LibXML::Class` it is recommended to refer to [`AttrX::Mooish`](https://modules.raku.org/dist/AttrX::Mooish) modules since it is used to back lazy deserialization of attributes.

  * More detailed code from synopsis can be found in *./examples/synopsis.raku* of this distribution.

  * [`LibXML::Class`](docs/md/LibXML/Class.md)

