use v6.e.PREVIEW;
unit class LibXML::Class::Config;
use experimental :will-complain;

use AttrX::Mooish;
use LibXML::Config;
use LibXML::Element;

use LibXML::Class::HOW::Element;
use LibXML::Class::Node;
use LibXML::Class::X;
use LibXML::Class::XML;

enum SerializeSeverity is export(:types) <EASY WARN STRICT>;

class NSMapType {
    has Str:D $.ns is required;
    has Str:D $.xml-name is required;
}

has SerializeSeverity:D $.severity = WARN;

has Bool:D $.eager = False;

# Namespace -> element name -> class
has %!ns-map;

# Index of types registered with %!ns-map
has %!ns-map-types{Mu} is mooish(:lazy, :clearer);

has Mu:U $!xml-repr-role is mooish(:lazy) is built;

has LibXML::Config:D $.libxml-config is mooish(:lazy);

my $singleton;

method new(*%p) {
    if %p<severity>:exists {
        with %p<severity> {
            $_ = SerializeSeverity::{$_} if $_ ~~ Stringy;
        }
    }
    self.bless(|%p)
}

submethod TWEAK(:$ns-map) {
    self.set-ns-map($_) with $ns-map;
}

method !build-xml-repr-role {
    (do require ::('LibXML::Class')).WHO<XMLRepresentation>
}

method !build-ns-map-types {
    my %idx{Mu};

    for %!ns-map.keys -> $ns {
        for %!ns-map{$ns}.keys -> $xml-name {
            %idx.append: (%!ns-map{$ns}{$xml-name}) => NSMapType.new(:$ns, :$xml-name);
        }
    }
}

multi method COERCE(%cfg) { self.new(|%cfg) }

method document-class is pure is raw {
    ::('LibXML::Class::Document')
}

method libxml-config-class { LibXML::Config }

method build-libxml-config {
    self.libxml-config-class.new(:with-cache)
}

method global(*%c) {
    LibXML::Class::X::Config::ImmutableGlobal.new.throw if $singleton && %c;
    $singleton //= self.new(|%c)
}

proto method alert(|) is hidden-from-backtrace {*}
multi method alert(Str:D $message) is hidden-from-backtrace {
    samewith LibXML::Class::X::AdHoc.new(:$message)
}
multi method alert(Exception:D $ex) is hidden-from-backtrace {
    return if $!severity == EASY;
    if $!severity == WARN {
        warn $ex.message;
    }
    else {
        $ex.throw
    }
}

my LibXML::Class::XML:U %xmlizations{Mu:U};

proto xmlize(|) {*}

multi method xmlize(LibXML::Class::XML \obj, $) is pure { obj }

multi method xmlize(Mu:U $what, LibXML::Class::XML:U $with, Str :$xml-name) is raw {
    return %xmlizations{$what} if %xmlizations{$what}:exists;

    unless $what.HOW ~~ Metamodel::ClassHOW {
        LibXML::Class::X::NonClass.new(:type($what), :what('produce an implicit XML representation'));
    }

    my \xmlized = $what.^mixin($with);
    %xmlizations{$what} := xmlized;
    xmlized.HOW does LibXML::Class::HOW::Element;
    xmlized.^xml-set-explicit(False);
    xmlized.^xml-set-name($xml-name // $what.^shortname);
    my $*PACKAGE := xmlized;
    xmlized.^xml-imply-attributes(:!local);
    xmlized
}

multi method xmlize(Mu:D $obj, LibXML::Class::XML:U $with, Str :$xml-name) {
    ( %xmlizations{$obj.WHAT}:exists
        ?? %xmlizations{$obj.WHAT}
        !! samewith($obj.WHAT, $with, :$xml-name) ).clone-from($obj)
}

my subset NSMapEntry
    of Mu
    will complain { "expected either an xml-elemen type or a pair of element name and an xml-elemnt type, got " ~ .raku }
    where { $_ ~~ LibXML::Class::Node || ($_ ~~ Pair:D && .key ~~ Str:D && .value ~~ LibXML::Class::Node:U) };

proto method set-ns-map(|) {*}

multi method set-ns-map(LibXML::Class::Node:U $type) {
    with $type.HOW.xml-guess-default-ns {
        samewith $_, $type.^xml-default-name, $type;
    }
    else {
        LibXML::Class::X::Config::TypeNoNS.new(:$type).throw
    }
}

multi method set-ns-map(Str:D $namespace, LibXML::Class::Node:U $type) {
    if ($type.HOW.xml-guess-default-ns andthen $namespace !~~ $_) {
        LibXML::Class::X::Config::NSMismatch.new(:$type, :$namespace).throw
    }
    samewith $namespace, $type.^xml-default-name, $type
}

multi method set-ns-map(*%ns-map) {
    samewith %ns-map
}

multi method set-ns-map(%ns-map) {
    for %ns-map.kv -> Str:D $namespace, $entries {
        for $entries.List -> NSMapEntry $entry {
            samewith $namespace, $entry
        }
    }
}

multi method set-ns-map(Str:D $namespace, *@entries, *%map) {
    for @entries -> NSMapEntry $entry {
        samewith $namespace, $entry;
    }

    for %map.kv -> Str:D $xml-name, $type {
        samewith $namespace, $xml-name, $type;
    }
}

multi method set-ns-map(Str:D $namespace, Pair:D $entry) {
    samewith $namespace, $entry.key, $entry.value
}

multi method set-ns-map(Whatever, $, Mu:U $type) {
    LibXML::Class::X::Config::WhateverNS.new(:$type).throw
}

multi method set-ns-map(Str:D $namespace, Str:D $xml-name, LibXML::Class::XML:U $type) {
    if %!ns-map{$namespace}{$xml-name}:exists {
        LibXML::Class::X::Config::TypeDuplicate.new(:$type, :$xml-name, :$namespace).throw
    }

    if $type.^xml-default-name ne $xml-name && $!severity != EASY {
        warn "Default XML name of " ~ $type.^name ~ " differs from its registration name in the namespace map:\n"
            ~ "    registred as: " ~ $xml-name
            ~ "      default is: " ~ $type.^xml-default-name;
    }

    %!ns-map{$namespace}{$xml-name} := $type;
    self!clear-ns-map-types;
}

multi method set-ns-map(Str:D $namespace, Str:D $xml-name, Mu $type) {
    samewith($namespace, $xml-name, self.xmlize($type, $!xml-repr-role, :$xml-name))
}

method ns-map(::?CLASS:D: LibXML::Element:D $elem) is raw {
    %!ns-map{$elem.namespaceURI}
        andthen (.{my $xml-name = $elem.localName}:exists ?? .{$xml-name} !! Nil)
        orelse Nil
}

method ns-map-type(::?CLASS:D: Mu:U \typeobj, Str :$ns --> NSMapType) {
    if (my @variants = (%!ns-map-types{typeobj} // Empty)) > 1 && $ns.defined {
        @variants = @variants.grep(*.ns eq $ns);
    }

    unless @variants == 1 {
        self.alert: LibXML::Class::X::Config::TypeMapAmbigous.new(:type(typeobj), :@variants) if @variants > 1;
        return Nil
    }

    @variants.head
}

method in-ns-map(::?CLASS:D: LibXML::Element:D $elem --> Bool:D) {
    ? (%!ns-map{$elem.namespaceURI} andthen .{$elem.localName}:exists)
}