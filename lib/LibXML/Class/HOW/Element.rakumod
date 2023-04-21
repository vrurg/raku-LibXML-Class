use v6.e.PREVIEW;
unit role LibXML::Class::HOW::Element;

use AttrX::Mooish;

use LibXML::Class::Attr::XMLish;
use LibXML::Class::HOW::AttrContainer;
use LibXML::Class::HOW::Configurable;
use LibXML::Class::HOW::Explicit;
use LibXML::Class::HOW::Imply;
use LibXML::Class::NS;
use LibXML::Class::Types;
use LibXML::Class::X;
use LibXML::Class::Utils;

also does LibXML::Class::HOW::Configurable;
also does LibXML::Class::HOW::AttrContainer;
also does LibXML::Class::HOW::Explicit;
also does LibXML::Class::HOW::Imply;
also does LibXML::Class::NS;

# Default element name
has Str $!xml-name;
# Should we try using laziness for XMLValueElement attributes?
has Bool $!xml-lazy;

# List of xml-element roles
has $!xml-roles;

method compose(Mu \obj) is raw {

    callsame();

    # Now, as the class is fully composed, finalize its XMLization.

    # Collect data from consumed xml-element roles
    if $!xml-roles {
        for $!xml-roles -> Mu \xml-role {
            for xml-role.^xml-attrs.values -> LibXML::Class::Attr::XMLish:D $descriptor {
                my $attr = self.get_attribute_for_usage(obj, $descriptor.attr.name);
                self.xml-attr-register(obj, $descriptor.clone(:$attr));
            }

            merge-in-namespaces(self.xml-namespaces, xml-role.HOW.xml-namespaces);
        }
    }

    # Collect namespace maps from parent classes if there is any.
    for obj.^parents(:!local).grep({ .HOW ~~ ::?ROLE }) -> Mu \parent {
        merge-in-namespaces(self.xml-namespaces, parent.HOW.xml-namespaces);
    }

    unless self.xml-is-explicit(obj) {
        self.xml-imply-attributes(obj);
    }

    for self.xml-attrs(obj).values {
        self.xml-lazify-attr(obj, .attr);
    }

    obj
}

method compose_attributes(Mu \obj, |) {
    callsame();

    # Move XML attribute descriptors from xml-element roles to our registry and adjust them to point to class'
    # attribute objects.
    for self.role_typecheck_list(obj) -> Mu \ins_role {
        if ins_role.HOW ~~ LibXML::Class::HOW::AttrContainer {
            for ins_role.^xml-attrs.values -> LibXML::Class::Attr::XMLish:D $xml-attr {
                my $attr = self.get_attribute_for_usage(obj, $xml-attr.attr.name);
                self.xml-attr-register(obj, $xml-attr.clone(:$attr));
            }
        }
    }
}

method xml-set-name(Mu, Str:D $!xml-name) {}

method xml-register-role(Mu \obj, Mu \xml-role) {
    ($!xml-roles // ($!xml-roles := Array[Mu].new)).push: xml-role;
}

method xml-name(Mu) {
    $!xml-name
}

method xml-default-name(Mu \obj) {
    $!xml-name // obj.^shortname
}

method xml-set-ns-defaults(Mu, $ns) {
    self.xml-set-ns-from-defs($ns)
}

method xml-set-lazy(Mu, Bool:D $!xml-lazy) {}
method xml-is-lazy(Mu) { $!xml-lazy }

method xml-lazify-attr(Mu \obj, Attribute:D $attr) {
    my $attr-desc = self.xml-get-attr(obj, $attr);
    if $attr-desc.lazy // ($!xml-lazy && !is-basic-type($attr-desc.type)) {
        LibXML::Class::X::ReMooify.new(:$attr, :type(obj.WHAT)).throw if $attr ~~ AttrX::Mooish::Attribute;
        my $*PACKAGE = obj;
        my $xml-name = $attr-desc.xml-name;
        my Str:D $lazy = 'xml-deserialize-attr';
        my $clearer = 'xml-clear-' ~ $xml-name;
        my $predicate = 'xml-has-' ~ $xml-name;
        trait_mod:<is>($attr, :mooish(:$lazy, :$clearer, :$predicate));
    }
    $attr
}