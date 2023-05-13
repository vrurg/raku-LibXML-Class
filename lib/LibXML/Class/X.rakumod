use v6.e.PREVIEW;
unit module LibXML::Class::X;

use LibXML::Element;
use LibXML::Node;
use LibXML::Attr;

use LibXML::Class::Utils;

my sub type-or-instance(Mu $what) {
    ($what.defined ?? "an instance of " !! "a type object ") ~ $what.^name
}

role Base is Exception {}

class AdHoc does Base {
    has Str:D $.message is required;
}

class TypeCheck does Base is X::TypeCheck {
    has Any:D $.descriptor is required;
    has Str:D $.when is required;
    method message {
        "Type check failed for " ~ $!descriptor.descriptor-kind
            ~ " of " ~ $!descriptor.declarant.^name
            ~ " " ~ $!when ~ ";\n    " ~ self.explain
    }
}

class TraitPosition does Base {
    has Str:D $.trait is required;
    has Mu $.class is built(:bind) is required;
    has Mu $.role is built(:bind) is required;

    method message {
        "Trait '" ~ $.trait
            ~ "' cannot be used after the role '"
            ~ $!role.^name
            ~ "'. Best if it goes as the first entry after the class name, like this:\n  class "
            ~ $!class.^name ~ " is "
            ~ $!trait ~ " ... does "
            ~ $!role.^name ~ " ... \{"
    }
}

role Attr does Base {
    has Attribute:D $.attr is required;
    method message-attr {
        "attribute " ~ $!attr.name
    }
}

my class Attr::Sigil does Attr {
    has Str:D $.what is required;
    has Str $.why;
    method message {
        $.what ~ " cannot be used with " ~ $.attr.name.substr(0, 1) ~ "-sigilled " ~ self.message-attr
    }
}

my class Attr::NoNamespace does Attr {
    has Str $.why;
    method message {
        "Namespaces cannot be used with " ~ self.message-attr ~ |(": " ~ $_ with $!why)
    }
}

role NS does Base {};

my class NS::Definition does NS {
    my class NO-WHAT {}
    has Str:D $.why is required;
    has Mu $.what = NO-WHAT;
    method message {
        "Incorrect declaration of namespace: " ~ $.why ~ |(", got " ~ $.what.gist unless $.what === NO-WHAT)
    }
}

my class NS::Prefix does NS {
    has Str:D $.prefix is required;
    has Str $.what;
    has Str $.while;
    method message {
        "There is no namespace deinition for prefix '$!prefix'"
            ~ (" for " ~ $_ with $.what)
            ~ (" while " ~ $_ with $.while)
    }
}

my class NS::Namespace does NS {
    has Str:D $.namespace is required;
    has Str $.what;
    has Str $.while;
    method message {
        "There is no namespace '$!namespace'"
            ~ (" for " ~ $_ with $.what)
            ~ (" while " ~ $_ with $.while)
    }
}

my class NS::Mismatch does NS {
    has Str:D $.expected is required;
    has Str:D $.got is required;
    has Str:D $.what is required;

    method message {
        "Expected namespace '$.expected' doesn't match '$.got' for $.what"
    }
}

class UnsupportedType does Base {
    has Mu $.type is required;
    method message {
        "Unsupported type object " ~ $!type.^name
    }
}

role Redeclaration does Base {}

my class Redeclaration::Type does Redeclaration {
    has Mu $.type is built(:bind);
    has Str:D $.kind is required;
    has Str:D $.what is required;
    method message {
        $.kind.tclc ~ " " ~ $!type.^name ~ " is already declared as " ~ $.what
    }
}

my class Redeclaration::Attribute does Redeclaration {
    has $.desc is required;
    method message {
#        try {
#            CATCH { default { note .message } }
#            note "ATTR ", $.desc.kind;
#        }
        "Attribute " ~ $.desc.name ~ " is already declared as an XML " ~ $.desc.kind
    }
}

class UnknownNodeProp does Base {
    has Str:D $.prop is required;
    has Str:D $.what is required;
    has Mu $.value is required;

    method message {
        "Cannot set node property '$.prop' to " ~ $.value.gist
    }
}

role AttrDuplication does Base {
    has Attribute:D @.attr is required;
    has Mu:U $.type is required;

    method message-for {
        my $sfx = @!attr > 1 ?? "s" !! "";
        " for " ~ $!type.^name ~ " attribute$sfx " ~ @!attr.map(*.name).join(", ")
    }
}

my class AttrDuplication::Text does AttrDuplication {
    method message {
        "Multiple attributes are marked as #text recepients" ~ self.message-for
    }
}

my class AttrDuplication::Attr does AttrDuplication {
    has Str:D $.ns is required;
    has Str:D $.name is required;
    method message {
        "Multiple attributes claim XML "
            ~ @.attr.head.xml-kind ~ " '"
            ~ $.name ~ "' under namespace '"
            ~ $.ns ~ "'"
            ~ self.message-for
    }
}

my class AttrDuplication::XMLNode does AttrDuplication {
    has Str:D $.node-name is required;
    method message {
        "Duplicate XML node '" ~ $.node-name ~ "' found " ~ self.message-for
    }
}

class ReMooify does Base {
    has Attribute:D $.attr is required;
    has Mu:U $.type is required;
    method message {
        "Don't use lazy mode with attribute "
            ~ $!attr.name ~ " of " ~ $!type.^name
            ~ " to which :mooish trait is already applied"
    }
}

class UnclaimedNodes does Base {
    has LibXML::Node:D $.elem is required;
    has LibXML::Node:D @.unclaimed is required;
    method message {
        my @attrs = @!unclaimed.grep(LibXML::Attr);
        my @elems = @!unclaimed.grep(* !~~ LibXML::Attr);
        my sub unused(@n, $what) {
            @n
                ?? $what ~ (@n > 1 ?? "s" !! "") ~ ": " ~ @n.map(*.name).unique.join(", ")
                !! Empty
        }
        "Tag <" ~ $.elem.name ~ "> is not fully de-serialized, there "
            ~ (@!unclaimed > 1 ?? "are" !! "is") ~ " unused:\n  "
            ~ (unused(@attrs, "attribute"), unused(@elems, "element")).join("\n  ")
    }
}

role Deserialize does Base {
    # Destination type
    has Mu:U $.type is required;
}

my class Deserialize::BadValue does Deserialize {
    has Str:D $.value is required;
    method message {
        "XML value '" ~ $.value ~ "' cannot be deserialized into an object of type " ~ $!type.^name
    }
}

my class Deserialize::BadNode does Deserialize {
    has Str:D $.expected is required;
    has Str:D $.got is required;
    method message {
        "Expected $.expected but got $.got"
    }
}

my class Deserialize::NoNSMap does Deserialize {
    has LibXML::Element:D $.elem is required;
    method message {
        "No Raku type found for xml:any element '"
            ~ $!elem.name ~ "' "
            ~ ($!elem.namespaceURI andthen "in namespace '$_'" orelse "with no namespace")
    }
}

my class Deserialize::UnknownTag does Deserialize {
    has Str:D $.xml-name is required;
    method message {
        "Don't know how to deserialize a sequence element <" ~ $!xml-name
            ~ "> for sequence " ~ $!type.^name
    }
}

my class Deserialize::DuplicateTag does Deserialize {
    has $.desc1 is required;
    has $.desc2 is required;
    has Str:D $.name is required;
    has Str:D $.namespace is required;

    method message {
        "XML name '$.name' in namespace '$.namespace' is claimed by "
            ~ $.desc1.descriptor-kind ~ " and by " ~ $.desc2.descriptor-kind
            ~ " for type " ~ $!type.^name
    }
}

my class Deserialize::DuplicateType does Deserialize {
    has $.desc1 is required;
    has $.desc2 is required;
    has Str:D $.namespace is required;

    method message {
        "Item type '{$.desc1.type}' in namespace '$.namespace' is claimed by "
            ~ $.desc1.descriptor-kind ~ " and by " ~ $.desc2.descriptor-kind
            ~ " for type " ~ $!type.^name
    }
}

my class Deserialize::Role does Deserialize {
    has $.desc is required;
    method message {
        "Destination type for " ~ $!desc.descriptor-kind
            ~ " of type " ~ $!type.^name
            ~ " is role " ~ $!desc.nominal-type.^name
            ~ " for which no class can be inferred; consider using any-mapping or a custom deserializer"
    }
}

role Serialize does Base {
    has Mu:U $.type is required;
}

my class Serialize::Impossible does Serialize {
    has Mu $.what is required;
    has Str:D $.why is required;

    method message {
        "Cannot serialize " ~ ~ type-or-instance($.what) ~ " for xml-element " ~ $!type.^name ~ ": " ~ $.why
    }
}

role Config does Base {}

my class Config::ImmutableGlobal does Config {
    method message {
        "The global configuration object already exists and cannot be changed"
    }
}

my class Config::TypeNoNS does Config {
    has Mu:U $.type is required;
    method message {
        "Type " ~ $!type.^name
            ~ " doesn't have a default namespace, cannot be registered in the map. Try either:\n"
            ~ "  - add a positional default namespace argument to xml-element trait\n"
            ~ "  - if there are namespace definitions in xml-element arguments try using a prefix"
    }
}

my class Config::WhateverNS does Config {
    has Mu:U $.type is required;
    method message {
        "Whatever (*) namespace cannot be registerd in the namespace map; attempted for type " ~ $!type.^name
    }
}

my class Config::TypeDuplicate does Config {
    has Mu:U $.type is required;
    has Str:D $.xml-name is required;
    has Str:D $.namespace is required;
    method message {
        "Type " ~ $!type.^name
            ~ " cannot be registered as element '" ~ $.xml-name
            ~ "' because there is already an entry with this name in namespace '"
            ~ $.namespace ~ "'"
    }
}

my class Config::NSMismatch does Config {
    has Mu:U $.type is required;
    has Str:D $.namespace is required;
    method message {
        "Type " ~ $!type.^name
            ~ " cannot be registered under namespace '" ~ $.namespace
            ~ "' because type's default differs"
    }
}

my class Config::TypeMapAmbigous does Config {
    has Mu:U $.type is built(:bind) is required;
    has @.variants is required;
    method message {
        "Type '" ~ $!type.^name ~ "' cannot be unambiously mapped into an XML element; possible variants:"
        ~ @.variants.map({ "\n  <" ~ .xml-name ~ "> in namespace '" ~ .ns ~ "'" }).join
    }
}

role Sequence does Base {
    has Mu $.type is required;
}

my class Sequence::NoItemDesc does Sequence {
    method message {
        "Type " ~ $!type.^name ~ " is declared :sequence, but no item descriptions provided in the trait argument"
    }
}

my class Sequence::ChildType does Sequence {
    has Mu $.child-decl;

    method message {
        "Object of type "
            ~ $.child-decl.^name
            ~ " cannot be used as a child element declaration for sequnce type "
            ~ $!type.^name
    }
}

#my class Sequence::TagType does Sequence {
#    has Mu $.tag is required;
#    method message {
#        "Object of type " ~ $!tag.^name ~ " cannot be used as a sequence tag name"
#    }
#}

my class Sequence::NotAny does Sequence {
    has Str:D $.why is required;
    method message {
        "Sequence type " ~ $!type.^name ~ " is not xml:any, " ~ $.why
    }
}

class LazyIndex does Base {
    has Attribute:D $.attr is required;
    method message {
        "There is no element found for lazy attribute " ~ $.attr.name ~ " of " ~ $.attr.package.^name
    }
}

class NonClass does Base {
    has Mu:U $.type is required;
    has Str:D $.what is required;
    method message {
        "Non-class type object " ~ $!type.^name ~ " cannot be used to " ~ $.what
    }
}

role Trait does Base {
    has Str:D $.trait-name = $*LIBXML-CLASS-TRAIT;

    method !message-trait { "Trait '$.trait-name'" }
}

my class Trait::Argument does Trait {
    has Str:D $.why is required;
    has Str:D @.details;
    has Bool:D $.singular = False;
    method message {
        self!message-trait
            ~ " cannot be used with "
            ~ ($!singular ?? "this argument" !! "these arguments") ~ ": " ~ $.why
            ~ |("\n" ~ @!details.map("  - " ~ *).join("\n") if @!details)
    }
}

my class Trait::NonXMLType does Trait {
    has Mu $.type is required;
    method message {
        self!message-trait ~ " can only be used with an xml-element type object."
            ~ " Consider declaring " ~ $!type.^name ~ " with `is xml-element`."
    }
}