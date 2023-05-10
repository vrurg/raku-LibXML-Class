use v6.e.PREVIEW;
unit role LibXML::Class::Node;

use AttrX::Mooish:ver<1.0.0+>:api<1.0.0+>;
use LibXML::Namespace;
use LibXML::Element;

use LibXML::Class::NS;
use LibXML::Class::Utils;
use LibXML::Class::X;
use LibXML::Class::XML;

also does LibXML::Class::NS;

has Str:D $.xml-name is mooish(:lazy<xml-build-name>, :predicate);

method xml-apply-ns( ::?CLASS:D:
                     LibXML::Element:D $dest-elem,
                     Bool:D :$default = True,
                     Str :namespace(:xml-default-ns(:$ns)) is copy,
                     Str :xml-default-ns-pfx(:$prefix) is copy,
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
            if $_ {
                $dest-elem.setNamespace($_)
            }
            else {
                # We cannot use just setNamespace when $ns is empty because it'd be ignored and the element would
                # inherit the default of its parent element. Also, adding an explicit namespace object results in
                # xmlns attribute to be used no matter if the parent element has the same default NS. Therefore we
                # manually check if only do it if the parent's default is non-empty.
                if $dest-elem.lookupNamespaceURI("") {
                    $dest-elem.add: LibXML::Namespace.new(:URI($_));
                }
            }
        }
        if $prefix {
            with $dest-elem.lookupNamespaceURI($prefix) -> $pfxNS {
                $dest-elem.setNamespace: $pfxNS, $prefix;
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
