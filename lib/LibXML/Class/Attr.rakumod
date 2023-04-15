use v6.e.PREVIEW;
unit module LibXML::Class::Attr;

use LibXML::Element;

use LibXML::Class::Attr::XMLish;
use LibXML::Class::HOW::AttrContainer;
use LibXML::Class::Node;
use LibXML::Class::Types;
use LibXML::Class::X;
use LibXML::Class::XML;
use LibXML::Class::Utils;

# For attributes mapping into XML element attributes
class XMLAttribute does LibXML::Class::Attr::XMLish {
    method kind is pure { "attribute" }
}

# Name of the container element to wrap a list of sub-elements into.
role XMLContainer {
    has Str $.container;

    method outer-name { $!container || $.xml-name }
}

# For attributes mapping into XML elements
class XMLValueElement does LibXML::Class::Attr::XMLish does XMLContainer {
    # XML attribute which holds simple tag value:
    # <tag val="value"/> if $.value-attr is set to "val"
    # <tag>value</tag> if $.value-attr is not set
    has Str $.value-attr;

    # Is it a xs:any kind of element? If so, the final type would be looked up in namespace-based mapping in config.
    has Bool $.any;

    method xml-build-name {
        my \nominal-type = self.nominal-type;
        (!$!any && # xml:any kind of attribute must not use attribute's type name even if it's an xml-element
            ((nominal-type.HOW ~~ LibXML::Class::Node && nominal-type.HOW.xml-name)
                || (nominal-type !~~ BasicType && nominal-type.^shortname)))
            || self.LibXML::Class::Attr::XMLish::xml-build-name
    }

    method kind is pure { "value element" }

    method nominal-type is raw { nominalize-type($.type) }
}

# For attributes mapping into XML #text
class XMLTextNode does LibXML::Class::Attr::XMLish {
    # Should we trim any text before use?
    has Bool $.trim;

    method kind is pure { "text element" }
}

class XMLPositional is XMLValueElement {
    method kind is pure { "positional" }

    method nominal-type {
        nominalize-type((my \type = $.type) ~~ Positional ?? type.of !! type)
    }
}

class XMLAssociative is XMLValueElement {
    method kind is pure { "associative" }

    method nominal-type {
        nominalize-type((my \type = $.type) ~~ Associative ?? type.of !! type)
    }
}

our proto sub mark-attr-xml(|) {*}

multi sub mark-attr-xml(Attribute:D $attr, Bool:D :as-xml-text($)!, *%profile) {
    samewith($attr, attr-role => XMLTextNode, :%profile)
}

multi sub mark-attr-xml( Attribute:D $attr,
                         $pos-arg?,
                         Bool:D :$as-xml-element!,
                         *%profile )
{
    my $sigil = $attr.name.substr(0,1);
    my \attr-type = $attr.type;
    my Mu $descriptor-class :=
        $as-xml-element
        ?? $sigil eq '@' && attr-type ~~ Positional
            ?? XMLPositional
            !! $sigil eq '%' && attr-type ~~ Associative
                ?? XMLAssociative
                !! XMLValueElement
        !! XMLAttribute;

    %profile<xml-name> = $pos-arg if $pos-arg ~~ Str:D;

    if %profile<any> && $sigil ne '@' | '$' {
        LibXML::Class::X::Attr::Sigil.new(:$attr, :what('Trait argument :any')).throw
    }

    samewith($attr, :$descriptor-class, :%profile)
}

multi sub mark-attr-xml( Attribute:D $attr,
                         :$descriptor-class! is raw,
                         :%profile is copy )
{
    my \pkg = $*PACKAGE;

    unless pkg.HOW ~~ LibXML::Class::HOW::AttrContainer {
        LibXML::Class::X::Trait::NonXMLType.new(:trait-name($*LIBXML-CLASS-TRAIT), :type(pkg)).throw
    }

    if pkg.^xml-get-attr($attr, :local) {
        LibXML::Class::X::Redeclaration::Attribute.new(:$attr).throw
    }

    # Default basic type attributes to non-lazy mode.
    %profile<lazy> //= False if $attr.type ~~ BasicType;
    %profile<value-attr> = (%profile<attr>:delete) if %profile<attr>:exists;

    with %profile<ns> {
        if .List.grep({ $_ ~~ Pair && .value ~~ Str }) {
            LibXML::Class::X::Namespace::Definition.new(
                :why('prefix declaration is not allowed with xml-attribute ' ~ $attr.name),
                :got($_)
                ).throw
        }
    }

    pkg.^xml-attr-register: $descriptor-class.new(|%profile, :$attr);

    # Unless the owning package is manually marked as implicit any explicitly marked attribute turns it into an
    # explicit one.
    pkg.^xml-set-explicit(True);
}