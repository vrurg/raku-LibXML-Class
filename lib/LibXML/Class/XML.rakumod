use v6.e.PREVIEW;
unit role LibXML::Class::XML;

use AttrX::Mooish;

use LibXML::Node;

# Pure interface role

method clone-from(Mu:D) {...}
method from-xml(|) {...}
method to-xml(|) {...}
method xml-name(--> Str:D) {...}
method xml-backing {...}
method xml-deserialize-node(|) {...}
method xml-deserialize-element(|) {...}