use v6.e.PREVIEW;
unit role LibXML::Class::Attr::XMLish;
use LibXML::Class::Node;
use LibXML::Class::NS;
use LibXML::Class::X;

also does LibXML::Class::Node;

my class NO-SERIALIZER {}

# The original attribute the trait was applied to.
has Attribute:D $.attr handles <type name has_accessor is_built get_value> is required;

has Mu $!serializer is built(:bind) = NO-SERIALIZER;
has Mu $!deserializer is built(:bind) = NO-SERIALIZER;
# Should we make this particular attribute lazy? This would override owner's typeobject setting.
# Either way, the final word would be from LibXML::Class::Config.
has Bool $.lazy is built(:bind);

# If true the attribute should inherit its default namespace from the owning type object.
has Bool $.inherit;

submethod TWEAK(:$ns) {
    self.xml-set-ns-from-defs($_) with $ns;

    if $!inherit && (self.xml-default-ns || self.xml-default-ns-pfx) {
        warn "Property 'inherit' will be ignored for attribute "
            ~ $!attr.name ~ " because a namespace is already defined for it.";
    }
}

method kind(--> Str:D) {...}

method xml-build-name(::?CLASS:D:) { $!attr.name.substr(2) }

method has-serializer(::?CLASS:D:) { $!serializer !=== NO-SERIALIZER }
method has-deserializer(::?CLASS:D:) { $!deserializer !=== NO-SERIALIZER }

method serializer { $!serializer === NO-SERIALIZER ?? Nil !! $!serializer }
method deserializer { $!deserializer === NO-SERIALIZER ?? Nil !! $!deserializer }

# Either use attribute-specified namespace or inherit $from an object
method maybe-inherit-ns(::?CLASS:D:
                             LibXML::Node:D $lookup-node,
                             LibXML::Class::NS:D $from,
                             Bool :$resolve
                            )
{
    my ($URI, $prefix) = ($.xml-default-ns // $.xml-default-ns-pfx)
        ?? ($.xml-default-ns, $.xml-default-ns-pfx)
        !! ($!inherit
            ?? ($from.xml-default-ns, $from.xml-default-ns-pfx)
            !! ());

    # Return as is resolving not requested or when both are undefined making resolving impossible.
    return ($URI, $prefix) if !$resolve || !($URI.defined || $prefix.defined);

    self.xml-resolve-ns($lookup-node, $URI, $prefix, :what('attribute ' ~ $!attr.name))
}