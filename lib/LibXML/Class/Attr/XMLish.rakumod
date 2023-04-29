use v6.e.PREVIEW;
unit role LibXML::Class::Attr::XMLish;

my class NO-SERIALIZER {}

# The original attribute the trait was applied to.
has Attribute:D $.attr handles <type name has_accessor is_built get_value> is required;

# Where this attribute was originally declared
has Mu $.declarant is built(:bind) is required;

has Mu $!serializer is built(:bind) = NO-SERIALIZER;
has Mu $!deserializer is built(:bind) = NO-SERIALIZER;
# Should we make this particular attribute lazy? This would override owner's typeobject setting.
# Either way, the final word would be from LibXML::Class::Config.
has Bool $.lazy is built(:bind);

method kind(--> Str:D) {...}

method has-serializer(::?CLASS:D:) { $!serializer !=== NO-SERIALIZER }
method has-deserializer(::?CLASS:D:) { $!deserializer !=== NO-SERIALIZER }

method serializer { $!serializer === NO-SERIALIZER ?? Nil !! $!serializer }
method deserializer { $!deserializer === NO-SERIALIZER ?? Nil !! $!deserializer }