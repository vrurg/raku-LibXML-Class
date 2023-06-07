use v6.e.PREVIEW;
use Test::Async;
use LibXML::Class;
use LibXML::Class::Config :types;

# This example is borrowed from XML:any subtest of t/040-basic-serialization.rakutest

my constant TEST-NS1 = 'http://test1.namespace';
my constant TEST-NS2 = 'http://test2.namespace';
my constant TEST-NS3 = 'http://test3.namespace';

my class Record is xml-element('record') {
    has Str:D $.id is required;
    has Numeric:D $.amount is required;
}

my constant HEADER-NS = 'http://header.namespace';

my class HeaderRow is xml-element('hr', :ns(:hdr, :hdr(HEADER-NS))) {
    has Str:D $.title is xml-attribute is required;
    has Str:D $.body is xml-text is required;
}

my %config =
    severity => STRICT,
    :derive,
    # Using slightly varied syntax for each ns-map entry to demonstrate possible variants.
    ns-map => (
        HeaderRow, # Name and namespace will be picked up from the xml-element declaration
        (TEST-NS1) => (
            Record,
            "float" => Num,
            "string" => Str,
        ),
        (TEST-NS2) => {
            "rec" => Record,
            "size" => Num,
            "text" => Str,
        },
        # Same as TEST-NS3 constant
        "http://test3.namespace" => {
            "volume" => Numeric,
            "comment" => Stringy,
        }
    );

my class Root is xml-element(<root>, :derive, :ns(TEST-NS1, :pfx(TEST-NS3))) {
    has $.header is xml-element(:any, :ns(HEADER-NS));
    has $.data is xml-element(:any) is required;
    has Cool:D $.perm-name is xml-element(:any, :ns(TEST-NS1)) is required;
    has @.array is xml-element(:any);
}

my $header = HeaderRow.new(:title('testing things'), :body("lorem ipsum, та інша беліберда"));

my $root-orig = Root.new(:data("foo"), :array(1e0, 2e0, "some more"), :perm-name(pi), :$header);

my $serialized = $root-orig.to-xml(:%config);
say "All namespaces are default:";
say $serialized.Str(:format).indent(2);

my $root-copy = Root.from-xml: $serialized.Str, :%config;

cmp-deeply $root-copy, $root-orig, "both are the same";

dd $root-orig;
dd $root-copy;

say "\nDefault namespace is '", TEST-NS2, "'.";
say $root-orig.to-xml(:%config, :xml-default-ns(TEST-NS2)).Str(:format).indent(2);

say "\nDefault namespace prefix is 'pfx'";
say $root-orig.to-xml(:%config, :prefix<pfx>).Str(:format).indent(2);