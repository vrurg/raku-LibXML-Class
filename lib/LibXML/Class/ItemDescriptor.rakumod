use v6.e.PREVIEW;
unit class LibXML::Class::ItemDescriptor;

has Mu $.type is built(:bind) is required;
has Mu:D $.seq-how is built(:bind) is required; # The HOW object of type object-declarator
has Str $.ns;
has Str $.xml-name;
has Str $.value-attr;

multi method new(Mu:U \typeobj, *%c) {
    samewith(:type(typeobj), |%c)
}

method guess-ns(::?CLASS:D:) {
    $!ns // $!seq-how.xml-guess-default-ns
}