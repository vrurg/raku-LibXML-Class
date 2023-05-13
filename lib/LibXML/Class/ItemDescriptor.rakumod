use v6.e.PREVIEW;
unit class LibXML::Class::ItemDescriptor;

use LibXML::Class::Descriptor;
use LibXML::Class::HOW::Element;
use LibXML::Class::Utils;
use LibXML::Class::Types;

also does LibXML::Class::Descriptor;

has Mu $.type is built(:bind) is required;
has Mu:D $.seq-how is built(:bind) is required; # The HOW object of type object-declarator
has Str $.value-attr;
has Mu:U $.nominal-type = nominalize-type($!type);

multi method new(Mu:U \typeobj, *%c) {
    samewith(:type(typeobj), |%c)
}

method xml-build-name {
    $!type.HOW ~~ LibXML::Class::HOW::Element
        ?? $!type.^xml-name
        !! "" #die "Sequence item of type " ~ $!type.^name ~ " must have an explicit XML name"
}

method descriptor-kind {
    "sequence item " ~ ($.xml-name || $!type.^name)
}

method value-type(--> Mu) { $!type }

method config-derive is raw { $*LIBXML-CLASS-CONFIG andthen .derive.element }