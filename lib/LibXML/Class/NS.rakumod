use v6.e.PREVIEW;
unit role LibXML::Class::NS;

use AttrX::Mooish;
use LibXML::Node;
use LibXML::Element;

use LibXML::Class::Types;
use LibXML::Class::Utils;

has Str $.xml-default-ns;
has Str $.xml-default-ns-pfx;
has @.xml-namespaces;

method xml-set-ns-from-defs($ns-defs, Bool:D :$override = True) {
    my ($default-ns, $default-ns-pfx, $xml-ns) = parse-ns-definitions($ns-defs<>);
    if $override {
        $!xml-default-ns = $_ with $default-ns;
        $!xml-default-ns-pfx = $_ with $default-ns-pfx;
        @!xml-namespaces := $xml-ns<>;
    }
    else {
        $!xml-default-ns //= $_ with $default-ns;
        $!xml-default-ns-pfx //= $_ with $default-ns-pfx;
        @!xml-namespaces := (|@!xml-namespaces, |$xml-ns).List;
    }
}

method xml-collect-from-hows {
    self.^mro
        .map(-> \t { |(t, |t.^concretizations(:local, :transitive).map({ .^roles(:!transitive).head })) })
        .map({
            next unless .HOW ~~ ::?ROLE;
            .HOW.xml-namespaces
        }).flat
}

# Namespace support methods
method xml-init-ns-from-hows {
    my $how := self.HOW;
    if $how ~~ ::?ROLE {
        $!xml-default-ns //= $how.xml-default-ns;
        $!xml-default-ns-pfx //= $how.xml-default-ns-pfx;
    }
    unless @!xml-namespaces {
        # Collect namespaces from all parents and consumed roles.
        @!xml-namespaces = self.xml-collect-from-hows.List;
    }
}

method xml-guess-default-ns {
    return $_ with $!xml-default-ns;
    return Nil without $!xml-default-ns-pfx;

    @!xml-namespaces.first(*.key eq $!xml-default-ns-pfx) andthen ($!xml-default-ns = .value) orelse Nil
}