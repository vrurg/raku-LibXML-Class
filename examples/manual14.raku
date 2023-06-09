use v6.e.PREVIEW;
use LibXML::Class;

class Record is xml-element(:ns(:foo)) {
    has Int:D $.count is xml-element is required;
}

class Meta is xml-element {
    has Str:D @.info is xml-element( :ns( :foo ) ) is required;
}

class Root is xml-element(<root>, :ns("http://test-ns", :pfx<http://pfx-ns>, :foo<http://foo-ns>)) {
    has Str:D $.key is xml-element(:ns) is required;
    has Record $.rec is xml-element;
    has Meta $.meta is xml-element;
}

my Root:D $root .=  new:
    :key<index>,
    rec => Record.new(:count(3)),
    meta => Meta.new(info => <inf1 inf2>);

my $serialized = $root.to-xml;
say $serialized.Str(:format);

# To see how namespace propagation works it's better to deserialize already serialized XML because by default libxml
# doesn't propagade namespaces according to XML rules when the document is being built from scratch. It only does it
# when parses from a string.
my $deserialized = Root.from-xml($serialized.Str).xml-document.libxml-document.documentElement;
say $deserialized[1][0], " default namespace: ", $deserialized[1][0].namespaceURI;
