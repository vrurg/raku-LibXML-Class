use v6.e.PREVIEW;
unit role LibXML::Class::Attr::XMLish;

use AttrX::Mooish;
use LibXML::Class::Utils;

# The original attribute the trait was applied to.
has Attribute:D $.attr handles <type name has_accessor is_built get_value package> is required;

# Should we make this particular attribute lazy? This would override owner's typeobject setting.
# Either way, the final word would be from LibXML::Class::Config.
has Bool $.lazy is built(:bind);

has Mu:U $.value-type is mooish(:lazy, :predicate);
has Mu:U $.nominal-type is mooish(:lazy, :predicate);

method kind(--> Str:D) {...}

method build-nominal-type is raw {
    nominalize-type($!value-type)
}

method build-value-type is raw {
    my \type = $!attr.type;
    my $sigil := $.sigil;
    ($sigil eq '@' && type ~~ Positional) || ($sigil eq '%' && type ~~ Associative)
        ?? type.of
        !! type
}

method sigil { $!attr.name.substr(0,1) }

# Copyright (c) 2023, Vadim Belman <vrurg@cpan.org>
#
# See the LICENSE file for the license