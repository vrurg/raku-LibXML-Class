use v6.e.PREVIEW;
use LibXML::Class;
use LibXML::Element;

proto sub serializer(|) {*}
multi sub serializer(LibXML::Element:D $elem, Real:D @vector) {
    for ^@vector.elems -> $pos {
        $elem.setAttribute("v" ~ $pos, @vector[$pos].Str);
    }
}
multi sub serializer(LibXML::Element:D $velem, Version:D $v --> Nil) {
    $velem.appendText: "Version: " ~ $v;
}
multi sub serializer(LibXML::Element:D $elem, Real:D %r) {
    $elem.setAttribute:
        'ratios', %r.sort.map({ .key ~ ":" ~ (.value * 100) ~ "%;" }).join
}
multi sub serializer(Date:D $d) {
    $d.DateTime.in-timezone(-5 * 3600).Str
}

class Record is xml-element<record> {
    has Real:D @.vector is xml-element(:&serializer);
    has Version:D @.ver is xml-element(:&serializer);
    has Real:D %.ratio is xml-element(:&serializer);
    has Dateish:D %.event is xml-element(:&serializer);
}

my $r =
    Record.new:
        vector => (π, e, 42, 13),
        ver => (v1, v42.12, v13.666),
        ratio => %(
            level => .15,
            volume => .42,
            whatever => 1.13,
        ),
        event => %(
            holiday => Date.new('2000-01-01'),
            reminder => DateTime.now.later(days => 5),
        );

say $r.to-xml.Str(:format);