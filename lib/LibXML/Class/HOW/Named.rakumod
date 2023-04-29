use v6.e.PREVIEW;
unit role LibXML::Class::HOW::Named;

# Default element name
has Str $!xml-name;

method xml-set-name(Mu, Str:D $!xml-name) {}

method xml-has-name(Mu) { $!xml-name.defined }

method xml-name(Mu $?) {
    $!xml-name
}

method xml-default-name(Mu \obj) {
    $!xml-name // obj.^shortname
}
