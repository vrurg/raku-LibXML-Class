use v6.e.PREVIEW;
unit role LibXML::Class::HOW::Element;

use AttrX::Mooish;

use LibXML::Class::Attr::XMLish;
use LibXML::Class::HOW::AttrContainer;
use LibXML::Class::HOW::Configurable;
use LibXML::Class::HOW::Explicit;
use LibXML::Class::HOW::Imply;
use LibXML::Class::HOW::Named;
use LibXML::Class::NS;
use LibXML::Class::Types;
use LibXML::Class::X;
use LibXML::Class::Utils;

also does LibXML::Class::HOW::Configurable;
also does LibXML::Class::HOW::AttrContainer;
also does LibXML::Class::HOW::Explicit;
also does LibXML::Class::HOW::Imply;
also does LibXML::Class::HOW::Named;
also does LibXML::Class::NS;

# Should we try using laziness for XMLValueElement attributes?
has Bool $!xml-lazy;

# List of xml-element roles
has $!xml-roles;

method xml-compose-element(Mu \obj) {
    my $check-pun = self.is_pun(obj);
    my \pun-source = self.pun_source(obj);

    my sub setup-from-pun-role(Mu \pun-role) {
        self.xml-set-name(obj, $_) with pun-role.^xml-name;
        my @ns-defs;
        @ns-defs.push: $_ with pun-role.HOW.xml-default-ns;
        @ns-defs.push: $_ => True with pun-role.HOW.xml-default-ns-pfx;
        self.xml-set-ns-from-defs(@ns-defs) if @ns-defs;
    }

    # Pun could happen either over a role group or a particular role object. If it's a group then we would need to
    # iterate over registered roles and find the one which belongs to the group. But if we know it immediately then
    # we just borrow its name for the pun class.
    if $check-pun && pun-source.HOW ~~ LibXML::Class::HOW::Named {
        setup-from-pun-role(pun-source);
        $check-pun = 0; # No need try each registered xml-element role to find the one.
    }

    # Collect data from consumed xml-element roles
    if $!xml-roles {
        for $!xml-roles -> Mu \xml-role {
            for xml-role.^xml-attrs.values -> LibXML::Class::Attr::XMLish:D $descriptor {
                my $attr = self.get_attribute_for_usage(obj, $descriptor.attr.name);
                self.xml-attr-register(obj, $descriptor.clone(:$attr));
            }

            if $check-pun && xml-role.^group =:= pun-source {
                setup-from-pun-role(xml-role);
                $check-pun = 0;
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

method compose_meta_methods(Mu \obj) {
    callsame();

    # Call this method here because when a role converts a class into an XMLRepresentation and applies this role to
    # class' HOW the 'compose' method is already being running. This method is the last one it class unconditionally
    # and makes it best place to do our job since the class itself is basically all ready by now.
    # XXX Very implementation dependent!
    self.xml-compose-element(obj);
}

method xml-register-role(Mu \obj, Mu \xml-role) {
    ($!xml-roles // ($!xml-roles := Array[Mu].new)).push: xml-role;
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