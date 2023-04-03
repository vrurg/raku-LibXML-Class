use v6.e.PREVIEW;
unit role LibXML::Class::Node;

use AttrX::Mooish:ver<1.0.0+>:api<1.0.0+>;

use LibXML::Class::NS;
use LibXML::Class::Utils;
use LibXML::Class::X;

also does LibXML::Class::NS;

has Str:D $.xml-name is mooish(:lazy<xml-build-name>, :predicate);

# Produce a namespace object for node's default NS
method xml-get-ns-default(LibXML::Node:D $lookup-node --> LibXML::Namespace:D) {
    my $default-pfx = $.xml-default-ns-pfx;
    return Nil unless $.xml-default-ns || $default-pfx;
#    note "default ns: ", $.xml-default-ns.raku, "\n",
#         "default pfx: ", $.xml-default-ns-pfx.raku;
#    without $.xml-default-ns {
#        note "USING LOOKUP NODE: ", $lookup-node.Str;
#        note "Lookup by prefix: ", $lookup-node.lookupNamespaceURI( $.xml-default-ns-pfx ).raku;
#    }
    my $URI = $.xml-default-ns // $lookup-node.lookupNamespaceURI( $default-pfx );
#    note "DEFAULT NS URI: ", $URI.raku;
    LibXML::Namespace.new(:$URI, :prefix($default-pfx))
}

method xml-apply-ns(::?CLASS:D: LibXML::Element:D $dest-elem, Bool:D :$default = True --> LibXML::Element:D) {
    note "??? XML NAMESPACES on ", self.^name, ": ", @.xml-namespaces;
    for @.xml-namespaces -> (:key($prefix), :value($URI)) {
        note "  + NS $prefix => $URI";
        $dest-elem.setNamespace($URI, $prefix, :!activate);
    }

    if $default {
        with self.xml-get-ns-default($dest-elem) {
            note "  + DEFAULT NS: ", .declaredPrefix.raku, " => ", .declaredURI;
            $dest-elem.setNamespace(.declaredURI, .declaredPrefix);
        }
    }

    $dest-elem
}
