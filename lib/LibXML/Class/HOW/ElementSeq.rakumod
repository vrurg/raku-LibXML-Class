use v6.e.PREVIEW;
# WITH-HOW defined the base HOW role we must also apply.
unit role LibXML::Class::HOW::ElementSeq[::WITH-HOW];

also does WITH-HOW;

# Tags allowed for sequence
has Map $!xml-sequence-tags;

# Types allowed for sequence
has List $!xml-sequence-types;

has Mu $!xml-deserializer;
has Mu $!xml-serializer;

has Bool $!xml-any;

method xml-set-sequence-tags(Mu, \tags) {
    $!xml-sequence-tags := tags.Map
}

method xml-set-sequence-types(Mu, \types) {
    $!xml-sequence-types := types.List;
}

method xml-set-sequence-any(Mu, Bool:D $!xml-any) {}

method xml-set-serialization(Mu, Mu $!xml-serializer, Mu $!xml-deserializer) {}

method xml-sequence-tags(Mu) is raw  { $!xml-sequence-tags // Map.new }
method xml-sequence-types(Mu) is raw { $!xml-sequence-types // ()     }
method xml-is-any(Mu) { $!xml-any }
method xml-serializer(Mu) { $!xml-serializer }
method xml-deserializer(Mu) { $!xml-deserializer }
