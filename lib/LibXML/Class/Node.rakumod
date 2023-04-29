use v6.e.PREVIEW;
unit role LibXML::Class::Node;

use AttrX::Mooish:ver<1.0.0+>:api<1.0.0+>;

use LibXML::Class::NS;
use LibXML::Class::Utils;
use LibXML::Class::X;

also does LibXML::Class::NS;

has Str:D $.xml-name is mooish(:lazy<xml-build-name>, :predicate);

method xml-apply-ns( ::?CLASS:D:
                     LibXML::Element:D $dest-elem,
                     Bool:D :$default = True,
                     Str :namespace(:$ns) is copy,
                     Str :$prefix is copy,
                     :$config = $*LIBXML-CLASS-CONFIG
    --> LibXML::Element:D )
{
    for %.xml-namespaces.pairs -> (:key($prefix), :value($ns)) {
        $dest-elem.setNamespace($ns, $prefix, :!activate);
    }

    if $default || ($ns // $prefix).defined {
        without $ns // $prefix {
            $ns = $.xml-default-ns;
            $prefix = $.xml-default-ns-pfx;
        }
        with $ns {
            $dest-elem.setNamespace($_, "");
        }
        with $prefix {
            with $dest-elem.lookupNamespaceURI($_) -> $pfxNS {
                $dest-elem.setNamespace: $pfxNS, $_;
            }
            else {
                if $config {
                    $config.alert:
                        LibXML::Class::X::NS::Prefix.new(
                            :$prefix,
                            :what("element <" ~ $dest-elem.name ~ ">"))
                }
            }
        }
    }

    $dest-elem
}
