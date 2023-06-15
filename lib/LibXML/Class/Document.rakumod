use v6.e.PREVIEW;
unit class LibXML::Class::Document;

use LibXML::Document;
use LibXML::Element;

use LibXML::Class::Config;
use LibXML::Class::XML;
use LibXML::Class::Utils;
use LibXML::Class::Types;

has LibXML::Document $.libxml-document;

has LibXML::Class::Config:D $.config .= global;

has Array[Mu] %!deserializations;

proto method parse(|) {*}
multi method parse(::?CLASS:U: LibXML::Class::Config :$config is copy, |c) {
    $config //= LibXML::Class::Config.global;
    my $libxml-config = $config.libxml-config;
    my LibXML::Document:D $libxml-document =
        $libxml-config.class-from(LibXML::Document).parse(config => $config.libxml-config, |c);
    self.new: :$libxml-document, :$config
}
multi method parse(::?CLASS:D: |c) {
    $!libxml-document .= parse(config => $.config.libxml-config, |c);
    self
}

method add-deserialization(::?CLASS:D: LibXML::Class::XML:D $repr) {
    return unless $!config.deserialization-registry && $!config.global-index;
    %!deserializations{$_}.push: $repr with $repr.xml-unique-key;
}

method remove-deserialization(::?CLASS:D: LibXML::Class::XML:D $repr) {
    return unless $!config.deserialization-registry && $!config.global-index;
    with $repr.xml-unique-key {
        %!deserializations{$_} = %!deserializations{$_}.grep(*.xml-id != $repr.xml-id);
    }
}

method deserializations(::?CLASS:D: LibXML::Element:D $elem) {
    %!deserializations.AT-KEY($elem.unique-key)
        andthen (|$_)
        orelse ()
}

proto method has-deserialization(::?CLASS:D: $) {*}
multi method has-deserialization(::?CLASS:D: LibXML::Element:D $elem) {
    %!deserializations.EXISTS-KEY($elem.unique-key)
}
multi method has-deserialization(::?CLASS:D: Str:D $key) {
    %!deserializations.EXISTS-KEY($key)
}

proto method find-deserializations(::?CLASS:D: $) {*}

multi method find-deserializations(::?CLASS:D: LibXML::Node:U $) {
    ().Seq
}

# We do not consider #document a deserializable thing as it stands above/aside of every other kind of XML entity
multi method find-deserializations(::?CLASS:D: LibXML::Document:D $) { ().Seq }

multi method find-deserializations(::?CLASS:D: LibXML::Node:D $node, Bool:D :$resolve-as-object = False --> Seq:D) {
    my $unique-key = $node.unique-key;
    return .Seq with %!deserializations{$unique-key};

    # If the node is not registered then try to locate a registered parent and unwind the nestings back by deserializing
    # all missing parents and the node itself.
    gather for self.find-deserializations($node.parent, :resolve-as-object) -> $candidate {
        # When found candidates is not an XMLObject it could be a deserialized value. In this case if the requested
        # $node is an attribute or a #text then it belongs to a simple XML element which value we just've found and it's
        # the result of coercing of the attribute or the #text.
        $candidate ~~ LibXML::Class::XML
            ?? (take $_ for $candidate.xml-find-deserializations($node, :$resolve-as-object))
            !! $candidate ~~ Failure
                ?? take $candidate
                !! $node ~~ LibXML::Attr | LibXML::Text
                    ?? take $candidate
                    !! take LibXML::Class::X::NoDeserialization.new(:$node).Failure
    }
}

multi method find-deserializations(::?CLASS:D: Iterable:D \nodes, Bool:D :$resolve-as-object = False) {
    gather for nodes -> \node {
        take $_ for self.find-deserializations(node, :$resolve-as-object)
    }
}

method findnodes(::?CLASS:D: |c) {
    fail LibXML::Class::X::Deserialization::NoBacking.new(:type(self.WHAT), :what("findnodes"))
        without $!libxml-document;

    $!libxml-document.findnodes(|c).map: { |self.find-deserializations($_) }
}

# Copyright (c) 2023, Vadim Belman <vrurg@cpan.org>
#
# See the LICENSE file for the license