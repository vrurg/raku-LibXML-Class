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
my $root-doc = $root-copy.xml-document;
my $xml-root = $root-doc.libxml-document.documentElement;
my $amount-elem = $xml-root[0][1];
is $root-doc.find-deserializations($amount-elem), (42.12,), "first <amount> element value is 42.12";
cmp-ok $root-doc.find-deserializations($xml-root[1]).head, '===', $root-copy.record[1], "second <record> element deserialization found";

cmp-deeply $root-copy, $root, "both are the same";
