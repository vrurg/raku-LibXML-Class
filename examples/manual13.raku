use v6.e.PREVIEW;
use LibXML::Class;

class Record is xml-element(:ns("ns1")) {
    has Int:D $.count is required;
}

class Meta is xml-element {
    has Str:D @.info is required;
}

class Root1 is xml-element(<root>, :impose-ns, :ns("test-ns", :pfx, :pfx<pfx-ns>)) {
    has Str:D $.key is xml-element is required;
    has Record $.rec is xml-element;
    has Meta $.meta is xml-element;
}

class Root2 is xml-element(<root>, :impose-ns, :ns("test-ns", :pfx, :pfx<pfx-ns>)) {
    has Str:D $.key is xml-element is required;
    has Record $.rec is xml-element(:!ns);
    has Meta $.meta is xml-element;
}

my Root1:D $root1 .=  new:
    :key<index>,
    rec => Record.new(:count(3)),
    meta => Meta.new(info => <inf1 inf2>);

say $root1.to-xml.Str(:format);

my Root2:D $root .= new:
        :key<index>,
        rec => Record.new(:count(3)),
        meta => Meta.new(info => <inf1 inf2>);

say $root.to-xml.Str(:format);