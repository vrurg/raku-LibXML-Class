use v6.e.PREVIEW;
unit role LibXML::Class::NS;

use AttrX::Mooish;
use LibXML::Namespace;
use LibXML::Node;
use LibXML::Element;

use LibXML::Class::Types;
use LibXML::Class::Utils;

has Str $!xml-default-ns;
has Str $!xml-default-ns-pfx;
has $!xml-namespaces;

submethod TWEAK(Str :$!xml-default-ns, Str :$!xml-default-ns-pfx, :$xml-namespaces) {
    $!xml-namespaces := OHash.new(|$_) with $xml-namespaces;
}

method xml-default-ns(::?CLASS:D:) { $!xml-default-ns }
method xml-default-ns-pfx(::?CLASS:D:) { $!xml-default-ns-pfx }

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
                LibXML::Class::X::NS::Definition.new(:$why, :$what).throw
            }

            when Str:D {
                bad-ns("default namespace is already '$default-ns'", $ns-def) with $default-ns;
                $default-ns := $_;
            }
            when Whatever {
                LibXML::Class::X::NS::Definition.new(:why("default namespace '*' is not yet implemented")).throw
            }
            when Pair:D {
                bad-ns("prefix must be a string", .key) unless .key ~~ Str:D;
                if $ns-def.value === True {
                    bad-ns("already have default prefix :" ~ $default-ns-pfx, ":"~ $ns-def.key) with $default-ns-pfx;
                    $default-ns-pfx := $ns-def.key;
                }
                else {
                    bad-ns("namespace of :{.key} must be a string", .value) unless .value ~~ Str:D;
                    @xml-ns.push: $_;
                }
            }
            default {
                bad-ns("must be a Pair object or a default namespace string", $_)
            }
        }
    }

    ($default-ns, $default-ns-pfx, @xml-ns.List)
}

method xml-set-ns-from-defs(::?CLASS:D: $ns-defs is copy, Bool:D :$override = True) {
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

# In terms of XML prefix has precedence over the default
method xml-guess-default-ns(::?CLASS:D: LibXML::Node :$resolve) {
    return $!xml-default-ns // ($resolve andthen .namespaceURI) // Nil without $!xml-default-ns-pfx;
    %.xml-namespaces{$!xml-default-ns-pfx}
        // ($resolve andthen .lookupNamespaceURI($!xml-default-ns-pfx))
        // fail LibXML::Class::X::NS::Prefix.new(
                    :prefix($!xml-default-ns-pfx),
                    :what(self.^name),
                    :while('guessing default namespace'))
}