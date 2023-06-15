use v6.e.PREVIEW;
use LibXML::Class;

my constant DEFAULT-NS = "http://app.namespace";
my constant TEST-NS1 = "http://test1.namespace";
my constant TEST-NS2 = "http://test2.namespace";

role Itemish is xml-element {
    my atomicint $next-id = 0;
    my sub next-id { $next-id⚛++ }
    has Int:D $.id = next-id;
}

class XSItem1 is xml-element('item1', :ns(TEST-NS1)) does Itemish {
    has Bool:D $.flag = False;
    has Str:D $.key is required;
}

class XSItem2 is xml-element('item2', :ns(TEST-NS2)) does Itemish {
    has Rat:D $.ratio is required;
}

my %config =
    ns-map => (
        XSItem1,
        XSItem2,
        "" => (
            "number" => Num,
        ),
        (DEFAULT-NS) => (
            "numeric" => Num,
            "stringy" => Str,
        ),
        (TEST-NS1) => (
            "size" => Int,
        ),
        (TEST-NS2) => (
            "volume" => Num,
            "annotation" => Str,
            "illegal" => Int,
        )
    );

class XSAny is xml-element(
    :any,
    :ns(DEFAULT-NS, :pfx(TEST-NS2)),
    :sequence(
        Itemish, Str, Num, (Int, :attr<value>, :ns(TEST-NS1))
    )) {}

my $xs-any = XSAny.new;
$xs-any.push: 1.234e-2;
$xs-any.push: "some text";
$xs-any.push: 42;

say "All defaults:";
say $xs-any.to-xml(:%config)
           .Str(:format).indent(2);

$xs-any = XSAny.new: :xml-default-ns("");
$xs-any.push: 42.12e0;
$xs-any.push: 1234;

say "No default namespace:";
say $xs-any.to-xml(:%config)
           .Str(:format).indent(2);

$xs-any = XSAny.new: xml-default-ns-pfx => "pfx";
$xs-any.push: 1.234e-2;
$xs-any.push: "some text";
$xs-any.push: 42;
$xs-any.push: XSItem2.new(ratio => 0.31415926);

say "With a prefix:";
my $serialized = $xs-any.to-xml(:%config);
say $serialized.Str(:format).indent(2);

my $deserialized = XSAny.from-xml: $serialized.Str, :%config, :prefix<pfx>;

note $deserialized.map(*.gist).join("\n");