use v6.e.PREVIEW;
use LibXML::Class;

class Record is xml-element(:ns(:foo)) {
    has Int:D $.count is xml-element is required;
    has Str:D $.item-name is xml-element(<item>, :!derive ) is required;
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
    rec => Record.new(:count(3), :item-name<Metchandize>),
    meta => Meta.new(info => <inf1 inf2>),
    :xml-default-ns-pfx<pfx>;

my $serialized = $root.to-xml;
say "No deriving:\n", $serialized.Str(:format).indent(2);

$serialized = $root.to-xml: :config{ :derive };
say "Deriving:\n", $serialized.Str(:format).indent(2);

my $deserialized;

say "Deserializing without :derive";
$deserialized = Root.from-xml: $serialized.Str, :prefix<pfx>;
say 'Attribute $.rec is deserialized: ', $deserialized.rec.defined;

say "Deserializing with :derive";
$deserialized = Root.from-xml: $serialized.Str, :prefix<pfx>, :config{:derive};
say 'Attribute $.rec is deserialized: ', $deserialized.rec.defined;