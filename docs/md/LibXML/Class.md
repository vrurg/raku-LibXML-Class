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
