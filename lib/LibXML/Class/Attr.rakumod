use v6.e.PREVIEW;
unit module LibXML::Class::Attr;
use experimental :will-complain;

use LibXML::Element;

use LibXML::Class::Attr::Node;
use LibXML::Class::Attr::XMLish;
use LibXML::Class::HOW::AttrContainer;
use LibXML::Class::Node;
use LibXML::Class::Types;
use LibXML::Class::X;
use LibXML::Class::XML;
use LibXML::Class::Utils;

# For attributes mapping into XML element attributes
class XMLAttribute does LibXML::Class::Attr::Node {
    submethod TWEAK {
        if self.xml-namespaces {
            LibXML::Class::X::NS::Definition.new(
                :why('prefix declaration is not allowed with xml-attribute ' ~ $!attr.name),
                :what($_)
                ).throw
        }
    }

    method kind is pure { "attribute" }
}

# Name of the container element to wrap a list of sub-elements into.
my subset AttrContainer of Any
    will complain { ":container of attribute's xml-element must either be a string or a boolean, not a " ~ .^name }
    where Str | Bool;

role XMLContainer {
    has AttrContainer $.container = False;

    method outer-name { self.container-name || $.xml-name }
    # Name of the container XML element
    method container-name {
        $!container
            ?? ($!container ~~ Str ?? $!container !! $.xml-name)
            !! Nil
    }
    # Name of the actual value XML element. If $value-type is passed in then it might be used to determine the name.
    method value-name(Mu $value is raw = Nil) {
        my \name-src = $value eqv Nil ?? $.type !! $value;
        $!container && $!container ~~ Bool
            ?? (name-src ~~ BasicType
                ?? Nil
                !! (name-src ~~ LibXML::Class::XML ?? name-src.xml-name !! name-src.^shortname))
            !! $.xml-name
    }
}

# For attributes mapping into XML elements
class XMLValueElement does LibXML::Class::Attr::Node does XMLContainer {
    # XML attribute which holds simple tag value:
    # <tag val="value"/> if $.value-attr is set to "val"
    # <tag>value</tag> if $.value-attr is not set
    has Str $.value-attr;

    # Is it a xs:any kind of element? If so, the final type would be looked up in namespace-based mapping in config.
    has Bool $!any is built;

#    method xml-build-name {
#        my \nominal-type = self.nominal-type;
#        (!$!any && # xml:any kind of attribute must not use attribute's type name even if it's an xml-element
#            ((nominal-type.HOW ~~ LibXML::Class::Node && nominal-type.HOW.xml-name)
#                || (nominal-type !~~ BasicType && nominal-type.^shortname)))
#            || self.LibXML::Class::Attr::XMLish::xml-build-name
#    }

    method kind is pure { "value element" }

    method nominal-type is raw { nominalize-type($.type) }

    method is-any { $!any }
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

multi sub mark-attr-xml(Attribute:D $attr, $pos-arg?, Bool:D :as-xml-text($)!, *@pos, *%profile) {
    # Don't throw here if there is more than one positional because the next candidate will report this case
    unless $pos-arg ~~ Bool || @pos {
        LibXML::Class::X::Trait::Argument.new(:why("only named arguments are accepted")).throw
    }
    samewith($attr, descriptor-class => XMLTextNode, :@pos, :%profile)
}

multi sub mark-attr-xml( Attribute:D $attr,
                         $pos-arg?,
                         Bool:D :$as-xml-element!,
                         *@pos,
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

    samewith($attr, :$descriptor-class, :@pos, :%profile)
}

# Make sure only certain nameds are used with attribute traits.
my proto sub no-extra-nameds(Mu, |) {*}
multi sub no-extra-nameds(XMLValueElement \kind, :value-attr($), :any($), :container($), :ns($), :xml-name($), *%rest) {
    nextwith(kind, |%rest)
}
multi sub no-extra-nameds(XMLAttribute \kind, :ns($), :xml-name($), *%rest) {
    nextwith(kind, |%rest)
}
multi sub no-extra-nameds(XMLTextNode \kind, :trim($), *%rest) {
    nextwith(kind, |%rest)
}
multi sub no-extra-nameds( LibXML::Class::Attr::XMLish,
                           :serializer($), :deserializer($), :lazy($), :inherit($),
                           *%rest )
{
    if %rest {
        my $singular = %rest.keys == 1;
        LibXML::Class::X::Trait::Argument.new(
            :$singular,
            :why("named" ~ ($singular ?? "" !! "s")
                ~ " '"
                ~ %rest.keys.sort.join("', '")
                ~ "'") ).throw
    }
}

multi sub mark-attr-xml( Attribute:D $attr,
                         :$descriptor-class! is raw,
                         :@pos,
                         :%profile is copy )
{
    my \pkg = $*PACKAGE;

    no-extra-nameds($descriptor-class, |%profile);

    if @pos {
        LibXML::Class::X::Trait::Argument.new(:why("too many positionals in trait arguments")).throw
    }

    unless pkg.HOW ~~ LibXML::Class::HOW::AttrContainer {
        LibXML::Class::X::Trait::NonXMLType.new(:trait-name($*LIBXML-CLASS-TRAIT), :type(pkg)).throw
    }

    if pkg.^xml-get-attr($attr, :local) -> $desc {
        LibXML::Class::X::Redeclaration::Attribute.new(:$desc).throw
    }

    with %profile<container> {
        if $_ && $_ ~~ Bool && $attr.type ~~ BasicType {
            LibXML::Class::X::Trait::Argument.new(
                :why(":container must specify an XML name when attribute is '" ~ $attr.type.^name ~ "'")).throw
        }
    }

    # Default basic type attributes to non-lazy mode.
    %profile<lazy> //= False if $attr.type ~~ BasicType;
    %profile<value-attr> = (%profile<attr>:delete) if %profile<attr>:exists;

    pkg.^xml-attr-register: $descriptor-class.new(|%profile, :declarant(pkg), :$attr);
}