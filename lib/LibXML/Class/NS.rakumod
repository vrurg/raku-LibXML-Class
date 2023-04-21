use v6.e.PREVIEW;
unit role LibXML::Class::NS;

use AttrX::Mooish;
use LibXML::Namespace;
use LibXML::Node;
use LibXML::Element;

use LibXML::Class::Types;
use LibXML::Class::Utils;

has Str $.xml-default-ns;
has Str $.xml-default-ns-pfx;
has $!xml-namespaces;

# Use this kinda-lazy method to provide support for MOP roles where %!xml-namespaces would be initialized into a
# BOOTHash and then newly-HLLized on every read.
method xml-namespaces(::?CLASS:D:) is raw {
    $!xml-namespaces // ($!xml-namespaces := OHash.new)
}

my sub parse-ns-definitions(+@ns-defs) is raw {
    my $default-ns := Nil;
    my $default-ns-pfx := Nil;
    my @xml-ns;
    for @ns-defs -> $ns-def {
        given $ns-def {

            my sub bad-ns(Str:D $why, Mu $what) {
                LibXML::Class::X::Namespace::Definition.new(:$why, :$what).throw
            }

            when Str:D {
                bad-ns("default namespace URI is already '$default-ns'", $ns-def) with $default-ns;
                $default-ns := $_;
            }
            when Whatever {
                LibXML::Class::X::Namespace::Definition.new(:why("default namespace '*' is not yet implemented")).throw
            }
            when Pair:D {
                bad-ns("prefix must be a string", .key) unless .key ~~ Str:D;
                if $ns-def.value === True {
                    bad-ns("already have default prefix :" ~ $default-ns-pfx, ":"~ $ns-def.key) with $default-ns-pfx;
                    $default-ns-pfx := $ns-def.key;
                }
                else {
                    bad-ns("URI of :{.key} must be a string", .value) unless .value ~~ Str:D;
                    @xml-ns.push: $_;
                }
            }
            default {
                bad-ns("must be a Pair object or a default URI value", $_)
            }
        }
    }

    ($default-ns, $default-ns-pfx, @xml-ns.List)
}

method xml-set-ns-from-defs(::?CLASS:D: $ns-defs, Bool:D :$override = True) {
    my ($default-ns, $default-ns-pfx, $xml-ns) = parse-ns-definitions($ns-defs<>);
    if $override {
        $!xml-default-ns = $_ with $default-ns;
        $!xml-default-ns-pfx = $_ with $default-ns-pfx;
        $!xml-namespaces := OHash.new: $xml-ns<>;
    }
    else {
        $!xml-default-ns //= $_ with $default-ns;
        $!xml-default-ns-pfx //= $_ with $default-ns-pfx;
        # Existing namespaces always override new ones.
        $!xml-namespaces := OHash.new(|$xml-ns, |($_ with $!xml-namespaces));
    }
}

method xml-guess-default-ns(::?CLASS:D:) {
#    say "??? GUESSING FOR ", self.WHICH, "\n",
#        "  default NS: ", $!xml-default-ns.raku, "\n",
#        "  default prefix: ", $!xml-default-ns-pfx, "\n",
#        "  xml namespaces: ", %!xml-namespaces.WHICH, " // ", %!xml-namespaces, "\n",
#        "                : ", %!xml-namespaces.keys.map({ $_ ~ ":" ~ %!xml-namespaces{$_} }).join(", ");
#    say "  --> ", (
#        $!xml-default-ns
#            // ($!xml-default-ns-pfx andthen %!xml-namespaces{$_})
#            // Nil
#    ).raku;
    $!xml-default-ns
        // ($!xml-default-ns-pfx andthen %.xml-namespaces{$_})
        // Nil
}

method xml-resolve-ns( LibXML::Node:D $lookup-node,
                       Str $URI is copy,
                       Str $prefix is copy,
                       :$what )
{
    my $pfxURI = $lookup-node.lookupNamespaceURI($_) with $prefix;

    if $prefix && !$pfxURI {
        LibXML::Class::X::Namespace::Prefix.new(:$prefix, :$what).throw
    }

    with $URI {
        # If prefix is set too then make sure they point out at the same NS
        with $prefix {
            LibXML::Class::X::Namespace::Mismatch.new(
                :expected($URI),
                :got($pfxURI),
                :what($what ~ " namespace prefix " ~ $prefix) ).throw
            if $URI ne $pfxURI
        }
        else {
            without $prefix = $lookup-node.lookupNamespacePrefix($URI) {
                LibXML::Class::X::Namespace::URI.new(:$URI, :$what).throw
            }
        }
    }
    else {
        $URI = $pfxURI
    }

    ($URI, $prefix)
}