use v6.e.PREVIEW;
unit class LibXML::Class::Config;
use experimental :will-complain;

use AttrX::Mooish;
use LibXML::Config;
use LibXML::Element;
use LibXML::Types;

use LibXML::Class::HOW::Element;
use LibXML::Class::Node;
use LibXML::Class::Types;
use LibXML::Class::X;
use LibXML::Class::XML;

also does LibXML::Class::Types::CloneFrom;

enum SerializeSeverity is export(:types) <EASY WARN STRICT>;

class NSMapType {
    has Str:D $.ns is required;
    has Str:D $.xml-name is required;
}

class Derive {
    has Bool $.attribute;
    has Bool $.element;

    multi method new(Bool:D $all-set) {
        self.new: :attribute($all-set), :element($all-set)
    }
    multi method new($options) {
        self.new: |$options.List.Capture
    }
}

has SerializeSeverity:D $.severity = WARN;

# Bypass laziness and deserialize immediately
has Bool:D $.eager = False;
# Default for :derive of xml-element trait
has Derive:D() $.derive .= new;

# Wether to keep registry of deserialized XML nodes
has Bool:D $.deserialization-registry = True;
# If false then the document object wouldn't track all XMLObject instances. Normally it would speed up searches if set,
# but the memory footprint might be bigger since every indexed object would stick around until the document itself
# is demolished.
has Bool:D $.global-index = True;

# Namespace -> element name -> class
has %!ns-map;

# Index of types registered with %!ns-map
has %!ns-map-types{Mu} is mooish(:lazy, :clearer);

has Mu:U $!xml-repr-role is mooish(:lazy) is built;

has LibXML::Config:D $.libxml-config is mooish(:lazy);

my $singleton;

method !fixup-profile(%p) {
    if %p<severity>:exists {
        with %p<severity> {
            $_ = SerializeSeverity::{$_} if $_ ~~ Stringy;
        }
    }
}

method new(*%p) {
    self!fixup-profile(%p);
    self.bless(|%p)
}

method clone(*%twiddles) {
    self!fixup-profile(%twiddles);
    my $cloned = callwith(|%twiddles);
    $cloned!clear-ns-map-types;
    $cloned.post-clone(%twiddles);
    $cloned
}

method post-clone(%twiddles) {
    with %twiddles<ns-map> {
        self.set-ns-map($_);
    }
}

submethod TWEAK(:$ns-map) {
    self.set-ns-map($_) with $ns-map;
}

method !build-xml-repr-role {
    LibXML::Types::resolve-package('LibXML::Class').WHO<XMLRepresentation>
}

method !build-ns-map-types {
    my %idx{Mu};

    for %!ns-map.keys -> $ns {
        for %!ns-map{$ns}.keys -> $xml-name {
            %idx.append: (%!ns-map{$ns}{$xml-name}) => NSMapType.new(:$ns, :$xml-name);
        }
    }

    %idx
}

multi method COERCE(%cfg) { self.new(|%cfg) }

method document-class is pure is raw {
    LibXML::Types::resolve-package('LibXML::Class::Document')
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

# Typecheck for $with must be over LibXML::Class::XML. Unfortunately, due to a bug in rakudo (my fault!)
# XMLRepresentation role doesn't typecheck against it. Therefore we stick to error-prone Mu:U.
multi method xmlize(Mu:U $what, Mu:U $with, Str :$xml-name) is raw {
    return %xmlizations{$what} if %xmlizations{$what}:exists;

    unless $what.HOW ~~ Metamodel::ClassHOW {
        LibXML::Class::X::NonClass.new(:type($what), :what('produce an implicit XML representation'));
    }

    # With this role overriding xml-create an xmlized class would deserialize into the original $what type instead of
    # $what+XMLRepresentation.
    my role XMLized[::FROM] {
        method xml-create(*%profile) { FROM.new: |%profile }
    }

    my \xmlized = $what.^mixin($with, XMLized[$what]);
    %xmlizations{$what} := xmlized;
    xmlized.HOW does LibXML::Class::HOW::Element;
    xmlized.^xml-set-explicit(False);
    # We cannot foresee side effects of lazyfing a class not supposed to be XML serialized or deserialized.
    xmlized.^xml-set-lazy(False);
    xmlized.^xml-set-name($xml-name // $what.^shortname);
    my $*PACKAGE := xmlized;
    xmlized.^xml-imply-attributes(:!local);
    xmlized
}

multi method xmlize(Mu:D $obj, Mu:U $with, Str :$xml-name) {
    ( %xmlizations{$obj.WHAT}:exists
        ?? %xmlizations{$obj.WHAT}
        !! samewith($obj.WHAT, $with, :$xml-name) ).clone-from($obj)
}

method !install-into-ns-map(Str:D $namespace, Str:D $xml-name, Mu $type) {
    if %!ns-map{$namespace}{$xml-name}:exists {
        LibXML::Class::X::Config::TypeDuplicate.new(:$type, :$xml-name, :$namespace).throw
    }

    my $how := $type.HOW;
    if $how ~~ LibXML::Class::HOW::Element
        && $type.^xml-default-name ne $xml-name
        && ($how.xml-default-ns // $how.xml-default-ns-pfx).defined
        && $!severity != EASY
    {
        warn "Default XML name of " ~ $type.^name ~ " differs from its registration name in the namespace map:"
            ~ "\n    registred as: " ~ $xml-name
            ~ "\n      default is: " ~ $type.^xml-default-name
            ~ "\n  This is likely to break de-serialization because the type uses own namespace.";
    }

    %!ns-map{$namespace}{$xml-name} := $type.WHAT;
    self!clear-ns-map-types;
}

my subset NSMapEntry
    of Mu
    will complain { "expected either an xml-element type or a pair of element name and a type, got " ~ .raku }
    where { $_ ~~ LibXML::Class::Node || ($_ ~~ Pair:D && .key ~~ Str:D && .value ~~ Mu:U) };

proto method set-ns-map(|) {*}

multi method set-ns-map(LibXML::Class::Node:U $type) {
    with $type.HOW.xml-guess-default-ns {
        self.set-ns-map: $_, $type.^xml-default-name, $type;
    }
    else {
        LibXML::Class::X::Config::TypeNoNS.new(:$type).throw
    }
}

multi method set-ns-map(Str:D $namespace, LibXML::Class::Node:U $type) {
    if ($type.HOW.xml-guess-default-ns andthen $namespace !~~ $_) {
        LibXML::Class::X::Config::NSMismatch.new(:$type, :$namespace).throw
    }
    self.set-ns-map: $namespace, $type.^xml-default-name, $type
}

multi method set-ns-map(*%ns-map) {
    self.set-ns-map: %ns-map
}

multi method set-ns-map(%ns-map) {
    for %ns-map.kv -> Str:D $namespace, $entries {
        for $entries.List -> NSMapEntry $entry {
            self.set-ns-map: $namespace, $entry
        }
    }
}

multi method set-ns-map(@ns-map) {
    for @ns-map -> $ns-map {
        self.set-ns-map: |$ns-map
    }
}

multi method set-ns-map(Str:D $namespace, *@entries, *%map) {
    for @entries -> NSMapEntry $entry {
        self.set-ns-map: $namespace, $entry;
    }

    for %map.kv -> Str:D $xml-name, $type {
        self.set-ns-map: $namespace, $xml-name, $type;
    }
}

multi method set-ns-map(Str:D $namespace, Pair:D $entry) {
    self.set-ns-map: $namespace, $entry.key, $entry.value
}

multi method set-ns-map(Whatever, $, Mu:U $type) {
    LibXML::Class::X::Config::WhateverNS.new(:$type).throw
}

multi method set-ns-map(Str:D $namespace, Str:D $xml-name, Mu $type) {
    self!install-into-ns-map($namespace, $xml-name, $type)
}

method ns-map(::?CLASS:D: LibXML::Element:D $elem) is raw {
    (%!ns-map{$elem.namespaceURI} // Nil)
        andthen (.{my $xml-name = $elem.localName}:exists ?? .{$xml-name} !! Nil)
}

method ns-map-type(::?CLASS:D: Mu:U \typeobj, Str :namespace(:$ns) --> NSMapType) {
    my @variants = (%!ns-map-types{typeobj} // ()).grep({ !$ns.defined || .ns eq $ns });

    unless @variants {
        @variants =
            %!ns-map-types
                .pairs
                .grep(-> $nsmap { typeobj ~~ $nsmap.key })
                .map({ .value.grep({ !$ns.defined || .ns eq $ns }).Slip });
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

# Copyright (c) 2023, Vadim Belman <vrurg@cpan.org>
#
# See the LICENSE file for the license