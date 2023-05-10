use v6.e.PREVIEW;
unit role LibXML::Class::Attr::XMLish;

use AttrX::Mooish;
use LibXML::Class::Utils;

my class NOT-SET {}

# The original attribute the trait was applied to.
has Attribute:D $.attr handles <type name has_accessor is_built get_value package> is required;

has Mu $!serializer is built(:bind) = NOT-SET;
has Mu $!deserializer is built(:bind) = NOT-SET;
# Should we make this particular attribute lazy? This would override owner's typeobject setting.
# Either way, the final word would be from LibXML::Class::Config.
has Bool $.lazy is built(:bind);

has Mu:U $.nominal-type = self!nominalize-attr;

method kind(--> Str:D) {...}

method !nominalize-attr is raw {
    my \type = $!attr.type;
    my $sigil = $.sigil;
    ($sigil eq '@' && type ~~ Positional) || ($sigil eq '%' && type ~~ Associative)
        ?? nominalize-type(type.of)
        !!  nominalize-type(type)
}

method has-serializer(::?CLASS:D:) { $!serializer !=== NOT-SET }
method has-deserializer(::?CLASS:D:) { $!deserializer !=== NOT-SET }

method serializer { $!serializer === NOT-SET ?? Nil !! $!serializer }
method deserializer { $!deserializer === NOT-SET ?? Nil !! $!deserializer }

method sigil { $!attr.name.substr(0,1) }