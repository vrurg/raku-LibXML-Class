use v6.e.PREVIEW;
unit class LibXML::Class::ItemDescriptor;

use LibXML::Class::NS;

also does LibXML::Class::NS;

has Mu $.type is built(:bind) is required;
has Mu:D $.seq-how is built(:bind) is required; # The HOW object of type object-declarator
has Str $.xml-name;
has Str $.value-attr;

multi method new(Mu:U \typeobj, *%c) {
    samewith(:type(typeobj), |%c)
}

submethod TWEAK(:$ns) {
    self.xml-set-ns-from-defs($ns) with $ns;
}

method guess-ns(::?CLASS:D:) {
    self.xml-guess-default-ns // $!seq-how.xml-guess-default-ns
}