use v6.e.PREVIEW;
unit module LibXML::Class::X;

use LibXML::Element;
use LibXML::Node;
use LibXML::Attr;

role Base is Exception {}

class AdHoc does Base {
    has Str:D $.message is required;
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

role Namespace does Base {};

my class Namespace::Definition does Namespace {
    has Str:D $.why is required;
    has Mu $.what is required;
    method message {
        "Incorrect declaration of namespace: " ~ $.why ~ ", got " ~ $.what.gist
    }
}

my class Namespace::Prefix does Namespace {
    has Str:D $.prefix is required;
    has Mu $.type is required;
    method message {
        "There is no namespace deinition for prefix '$!prefix' for type " ~ $!type.^name
    }
}

my class Namespace::Mismatch does Namespace {
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
    has Mu:U $.type is built(:bind);
    has Str:D $.kind is required;
    has Str:D $.what is required;
    method message {
        $.kind.tclc ~ " " ~~ $!type.^name ~~ " is already declared as " ~ $.what
    }
}

my class Redeclaration::Attribute does Redeclaration {
    has Attribute:D $.attr is required;
    method message {
        "Attribute " ~ $.attr.name ~ " is already declared as an XML " ~ $.attr.xml-kind
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
    has Str:D $.nsURI is required;
    has Str:D $.name is required;
    method message {
        "Multiple attributes claim XML "
            ~ @.attr.head.xml-kind ~ " '"
            ~ $.name ~ "' under namespace '"
            ~ $.nsURI ~ "'"
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
            ~ $!attr.name ~ " of " ~ $.type.^name
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
                ?? $what ~ (@n > 1 ?? "s" !! "") ~ @n.map(*.name).join(",")
                !! ""
        }
        "Tag <" ~ $.elem.name ~ "> is not fully de-serialized, there "
            ~ (@!unclaimed > 1 ?? "are" !! "is") ~ " unused:\n"
            ~ unused(@attrs, "attribute")
            ~ unused(@elems, "elements")
    }
}

role Deserialize does Base {
    # Destination type
    has Mu:U $.type is required;
}

my class Deserialize::BadValue does Deserialize {
    has Str:D $.value is required;
    method message {
        "XML value '" ~ $.value ~ "' cannot be deserialized into an object of type " ~ $.type.^name
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

role Serialize does Base {}

my class Serialize::Impossible does Serialize {
    has Mu $.what is required;
    has Str:D $.why is required;

    method message {
        "Cannot serialize " ~
            ($.what.defined ?? "an instance of " !! "a type object ") ~ $.what.^name
            ~ ": " ~ $.why
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
        "Type " ~ $.type.^name
            ~ " doesn't have a default namespace, cannot be registered in the map. Try either:\n"
            ~ "  - add a positional default namespace argument to xml-element trait\n"
            ~ "  - if there are namespace definitions in xml-element arguments try using a prefix"
    }
}

my class Config::WhateverNS does Config {
    has Mu:U $.type is required;
    method message {
        "Whatever (*) namespace cannot be registerd in the namespace map; attempted for type " ~ $.type.^name
    }
}

my class Config::TypeDuplicate does Config {
    has Mu:U $.type is required;
    has Str:D $.xml-name is required;
    has Str:D $.namespace is required;
    method message {
        "Type " ~ $.type.^name
            ~ " cannot be registered as element '" ~ $.xml-name
            ~ "' because there is already an entry with this name in namespace '"
            ~ $.namespace ~ "'"
    }
}

my class Config::NSMismatch does Config {
    has Mu:U $.type is required;
    has Str:D $.namespace is required;
    method message {
        "Type " ~ $.type.^name
            ~ " cannot be registered under namespace '" ~ $.namespace
            ~ "' because type's default differs"
    }
}

my class Config::TypeMapAmbigous does Config {
    has Mu:U $.type is built(:bind) is required;
    has @.variants is required;
    method message {
        "Type '" ~ $.type.^name ~ "' cannot be unambiously mapped into an XML element; possible variants:"
        ~ @.variants.map({ "\n  <" ~ .xml-name ~ "> in namespace '" ~ .ns ~ "'" }).join
    }
}

role Sequence does Base {
    has Mu $.type is built(:bind) is required;
}

my class Sequence::NoChildTypes does Sequence {
    method message {
        "Type " ~ $.type.^name ~ " is declared sequence but no child types provided in the trait argument"
    }
}

my class Sequence::ChildType does Sequence {
    has Mu $.child-decl;

    method message {
        "Object of type "
            ~ $.child-decl.^name
            ~ " cannot be used as a child element declaration for sequnce type"
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
        "Non-class type object " ~ $.type.^name ~ " cannot be used to " ~ $.what
    }
}

role Trait does Base {
    has Str:D $.trait-name is required;

    method !message-trait { "Trait '$.trait-name'" }
}

my class Trait::Argument does Trait {
    has Str:D $.why is required;
    method message {
        self!message-trait ~ " cannot be used with these arguments: " ~ $.why
    }
}

my class Trait::NonXMLType does Trait {
    has Mu $.type is required;
    method message {
        self!message-trait ~ " can only be used with an xml-element type object."
            ~ " Consider declaring " ~ $!type.^name ~ " with `is xml-element`."
    }
}