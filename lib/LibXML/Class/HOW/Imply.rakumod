use v6.e.PREVIEW;
unit role LibXML::Class::HOW::Imply;

use LibXML::Class::Attr;
use LibXML::Class::Types;
use LibXML::Class::XML;
use LibXML::Class::Utils;

method xml-attrs {...}

method xml-imply-attributes(Mu \obj, Bool:D :$local = True --> Nil) {
    die "It's a bad idea to implicitify attributes of an explicit type " ~ obj.^name if self.xml-is-explicit(obj);

    my @attrs;
    if $local {
        @attrs = self.attributes(obj, :local);
    }
    else {
        my SetHash $seen .= new;

        my sub collect-from-class(Mu $class is raw) {
            for $class.^attributes(:local) {
                unless $seen.EXISTS-KEY(my $aname = .name) {
                    @attrs.push: $_;
                    $seen.set: $aname;
                }
            }

            for $class.^parents(:local) -> Mu \parent {
                # We only collect from non-xml-element parents since others would take care of themselves.
                collect-from-class(parent) unless parent.HOW ~~ LibXML::Class::XML;
            }
        }

        collect-from-class(obj);
    }

    for @attrs.grep({ (.has_accessor || .is_built)
                        && !self.xml-has-attr(obj, .name, :local)
                        && !(.name.substr(2,4) eq 'xml-') })
        -> Attribute:D $attr
    {
        my $as-xml-element = !is-basic-type($attr.type);
        LibXML::Class::Attr::mark-attr-xml( $attr, :$as-xml-element, |(:derive if $as-xml-element) );
    }
}