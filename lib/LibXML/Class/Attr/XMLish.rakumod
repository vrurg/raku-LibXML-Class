use v6.e.PREVIEW;
unit role LibXML::Class::Attr::XMLish;
use LibXML::Class::Node;

also does LibXML::Class::Node;

my class NO-SERIALIZER is Nil {}

# The original attribute the trait was applied to.
has Attribute:D $.attr handles <type name has_accessor is_built get_value> is required;

has Mu $.serializer is built(:bind) = NO-SERIALIZER;
has Mu $.deserializer is built(:bind) = NO-SERIALIZER;
# Should we make this particular attribute lazy? This would override owner's typeobject setting.
# Either way, the final word would be from LibXML::Class::Config.
has Bool $.lazy is built(:bind);

submethod TWEAK(:$ns) {
    self.xml-set-ns-from-defs($_) with $ns;
}

method kind(--> Str:D) {...}

method xml-build-name { $!attr.name.substr(2) }

method has-serializer { $!serializer !=== NO-SERIALIZER }
method has-deserializer { $!deserializer !=== NO-SERIALIZER }
