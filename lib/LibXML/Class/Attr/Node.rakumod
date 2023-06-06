use v6.e.PREVIEW;
unit role LibXML::Class::Attr::Node;

use AttrX::Mooish;
use AttrX::Mooish::Attribute;

use LibXML::Class::Attr::XMLish;
use LibXML::Class::Descriptor;
use LibXML::Class::NS;
use LibXML::Class::Types;
use LibXML::Class::XML;

also does LibXML::Class::Attr::XMLish;
also does LibXML::Class::Descriptor;

method xml-build-name(::?CLASS:D:) { $.attr.name.substr(2) }

method descriptor-kind {
    "attribute " ~ $.attr.name
}

# Either use attribute-specified namespace, or derive $from an object, or take from attribute's type if it's an xml-element
method compose-ns(::?CLASS:D: Mu :$from = Nil, Bool:D :$resolve = False, *%c) {
    my (Str $namespace, Str $prefix) = self.infer-ns(:$from, |%c);

    # Return as is unless resolving is requested and either namespace or prefix defined,
    # so that resolving over them is possible.
    return ($namespace, $prefix) unless $resolve && ($namespace || $prefix);

    my Str $pfx-ns = (%.xml-namespaces{$_} // $from.lookupNamespaceURI($_)) with $prefix;

    my $what = "attribute " ~ $.attr.name;
    my $while = "resolving namespace";

    # Prefix is specified by there is not defined anywhere upstream
    if $prefix && !$pfx-ns {
        LibXML::Class::X::NS::Prefix.new(:$prefix, :$what, :$while).throw
    }

    with $namespace {
        # If prefix is set too then make sure they point out at the same NS
        with $prefix {
            LibXML::Class::X::NS::Mismatch.new(
                :expected($namespace),
                :got($pfx-ns),
                :what($what ~ " namespace prefix " ~ $prefix) ).throw
            if $namespace ne $pfx-ns

        }
        else {
            # When there is namespace but no prefix try locating it in upstream definitions
            without $prefix = $from.lookupNamespacePrefix($namespace) {
                LibXML::Class::X::NS::Namespace.new(:$namespace, :$what, :$while).throw
            }
        }
    }
    else {
        $namespace = $_ with $pfx-ns
    }

    ($namespace, $prefix)
}

method gist {
    self.descriptor-kind ~ " in " ~ $.declarant.^name
}

method lazify(Mu \obj) {
    LibXML::Class::X::ReMooify.new(:$.attr, :type(obj.WHAT)).throw if $.attr ~~ AttrX::Mooish::Attribute;
    my $xml-name = $.xml-name;
    my $lazy = 'xml-deserialize-attr';
    my $predicate = 'xml-has-' ~ $xml-name;
    &trait_mod:<is>($.attr, :mooish(:$lazy, :$predicate));
}