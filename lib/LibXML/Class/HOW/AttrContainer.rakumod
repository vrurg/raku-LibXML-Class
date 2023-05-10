use v6.e.PREVIEW;
unit role LibXML::Class::HOW::AttrContainer;

use LibXML::Class::Attr::XMLish;
use LibXML::Class::Types;

# Attributes we handle with this type object. Using ordered hash because it might be important for serialization.
has $!xml-attrs;
# All XML attributes of the class, including those from parent xml-element classes
has $!xml-attr-lookup;
# Impose type object namespace onto it's attributes with no explicit NS set.
has Bool $!xml-impose-ns = False;

method xml-attr-register(Mu \obj, LibXML::Class::Attr::XMLish:D $descriptor --> Nil) {
    self.xml-attrs(obj).{$descriptor.attr.name} := $descriptor;
    $!xml-attr-lookup := Nil;
}

method xml-attrs(Mu \obj, Bool :$local = True) {
    $local
        ?? ($!xml-attrs // ($!xml-attrs := OHash.new))
        !! ($!xml-attr-lookup
            // ($!xml-attr-lookup := OHash.new( obj.^mro.grep({ .HOW ~~ ::?ROLE }).reverse.map(*.^xml-attrs(:local).pairs) )))
}

method xml-get-attr(Mu \obj, $attr where Str:D | Attribute:D, Bool :$local = True) {
    self.xml-attrs(obj, :$local).{$attr ~~ Str:D ?? $attr !! $attr.name} // Nil
}

method xml-has-attr(Mu \obj, Str:D $name, Bool :$local = False) {
    self.xml-attrs(obj, :$local).EXISTS-KEY($name)
}

method xml-set-impose-ns(Mu, Bool:D() $!xml-impose-ns) {}

method xml-is-imposing-ns(Mu) is raw { $!xml-impose-ns }