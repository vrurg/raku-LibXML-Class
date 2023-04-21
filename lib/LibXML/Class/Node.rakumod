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
                     Str :$URI is copy,
                     Str :$prefix is copy,
                     :$config = $*LIBXML-CLASS-CONFIG
    --> LibXML::Element:D)
{
    for %.xml-namespaces.pairs -> (:key($prefix), :value($URI)) {
        $dest-elem.setNamespace($URI, $prefix, :!activate);
    }

    if $default || ($URI // $prefix).defined {
        without $URI // $prefix {
            $URI = $.xml-default-ns;
            $prefix = $.xml-default-ns-pfx;
        }
        with $URI {
            $dest-elem.setNamespace($_, "");
        }
        with $prefix {
            with $dest-elem.lookupNamespaceURI($_) -> $pfxURI {
                $dest-elem.setNamespace: $pfxURI, $_;
            }
            else {
                if $config {
                    $config.alert:
                        LibXML::Class::X::Namespace::Prefix.new(
                            :prefix($_),
                            :what("element <" ~ $dest-elem.name ~ ">")).throw
                }
            }
        }
    }

    $dest-elem
}
