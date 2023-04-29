use v6.e.PREVIEW;
unit role LibXML::Class::Attr::Node;

use LibXML::Node;
use LibXML::Class::Attr::XMLish;
use LibXML::Class::Node;
use LibXML::Class::NS;

also does LibXML::Class::Attr::XMLish;
also does LibXML::Class::Node;

# If true the attribute should inherit its default namespace from the owning type object.
has Bool $.inherit;

submethod TWEAK(:$ns) {
    self.xml-set-ns-from-defs($_) with $ns;

    if $!inherit && (self.xml-default-ns || self.xml-default-ns-pfx) {
        warn "Property 'inherit' will be ignored for attribute "
            ~ self.attr.name ~ " because namespace is already defined for it.";
    }
}

method xml-build-name(::?CLASS:D:) { $.attr.name.substr(2) }

# Either use attribute-specified namespace or inherit $from an object
method maybe-inherit-ns( ::?CLASS:D:
                         Mu :$from where { .WHAT =:= Nil || $_ ~~ $.declarant } = Nil,
                         LibXML::Node :$resolve )
{
    my (Str $namespace, Str $prefix);

    if ($.xml-default-ns // $.xml-default-ns-pfx) {
        # If the attribute has NS declaration – use it
        ($namespace, $prefix) = ($.xml-default-ns, $.xml-default-ns-pfx)
    }
    elsif $!inherit {
        # If the attribute is requested to inherit its NS information then either use what $from instance provides;
        # or what is declared on attribute's type object. In the latter case user can specify a subclass of attribute's
        # type object in $from.
        with $from {
            ($namespace, $prefix) = ($from.xml-default-ns, $from.xml-default-ns-pfx);
        }
        else {
            my \typeobj = $from.WHAT =:= Nil ?? $.declarant !! $from;
            ($namespace, $prefix) = (.xml-default-ns, .xml-default-ns-pfx)
                given (typeobj.HOW ~~ LibXML::Class::NS ?? typeobj.HOW !! typeobj.xml-class.HOW);
        }
    }

    # Return as is unless resolving is requested and either namespace or prefix defined,
    # so that resolving over them is possible.
    return ($namespace, $prefix) unless $resolve.defined && ($namespace // $prefix).defined;

    my Str $pfx-ns = $resolve.lookupNamespaceURI($_) with $prefix;

    my $what = "attribute " ~ $.attr.name;
    my $while = "resolving namespace";

    # Prefix is specified by there is not defined anywhere upstream
    if $prefix && !$pfx-ns {
        LibXML::Class::X::NS::Prefix.new(:$prefix, :$what, :$while).throw
    }

    with $namespace {
        # If prefix is set too then make sure they point out at the same NS
        with $prefix {
            LibXML::Class::X::NS::Mismatch.new(
                :expected($namespace),
                :got($pfx-ns),
                :what($what ~ " namespace prefix " ~ $prefix) ).throw
            if $namespace ne $pfx-ns

        }
        else {
            # When there is namespace but no prefix try locating it in upstream definitions
            without $prefix = $resolve.lookupNamespacePrefix($namespace) {
                LibXML::Class::X::NS::Namespace.new(:$namespace, :$what, :$while).throw
            }
        }
    }
    else {
        $namespace = $_ with $pfx-ns

    }

    ($namespace, $prefix)
}