use v6.e.PREVIEW;
unit role LibXML::Class::HOW::ElementRole;

use LibXML::Class::HOW::AttrContainer;
use LibXML::Class::HOW::Element;
use LibXML::Class::HOW::Explicit;
use LibXML::Class::HOW::Imply;
use LibXML::Class::HOW::Named;
use LibXML::Class::Utils;
use LibXML::Class::NS;

also does LibXML::Class::HOW::AttrContainer;
also does LibXML::Class::HOW::Explicit;
also does LibXML::Class::HOW::Imply;
also does LibXML::Class::HOW::Named;
also does LibXML::Class::NS;

method compose(Mu \obj) is raw {
    callsame();

    unless self.xml-is-explicit(obj) {
        self.xml-imply-attributes(obj, :local);
    }

    obj
}

method specialize(Mu \obj, Mu \target-class, |) is raw {
    my Mu \target-how = target-class.HOW;
    unless target-how ~~ LibXML::Class::HOW::Element {
        target-how does LibXML::Class::HOW::Element;
        require ::('LibXML::Class');
        target-class.^add_role(::('LibXML::Class::XMLRepresentation'));
        # Force the class to be explicit so we don't serialize its attributes unintentionally.
        target-class.^xml-set-explicit(True);
    }
    # Register on the target class so it wouldn't be later guessing what roles to collect data from.
    target-how.xml-register-role(target-class, obj);
    nextsame
}

method xml-set-ns-defaults(Mu, $ns) {
    self.xml-set-ns-from-defs($ns)
}