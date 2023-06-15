use v6.e.PREVIEW;
unit role LibXML::Class::Descriptor;

use LibXML::Node;
use LibXML::Element;

use LibXML::Class::Node;
use LibXML::Class::NS;
use LibXML::Class::X;

also does LibXML::Class::Node;

my class NOT-SET {
    method Bool { False }
}

has &.serializer is built(:bind);
has &.deserializer is built(:bind);

# If true then object must get its default namespace from the declarant type object or whatever is passed in :from
# of infer-ns method.
has Bool $.derive;

# Where this object was originally declared.
has Mu $.declarant is built(:bind) is required;

method nominal-type {...}
method value-type {...}
method config-derive {...}
method descriptor-kind(--> Str:D) {...}

submethod TWEAK(:$ns = NOT-SET) {
    self.xml-set-ns-from-defs( self.preprocess-ns($ns) );

    if $!derive {
        if !($!derive ~~ LibXML::Class::Types::IsImplicitValue)
            && (self.xml-default-ns || self.xml-default-ns-pfx)
        {
            warn "Property 'derive' will be ignored for " ~ self.descriptor-kind
                ~ " because namespace is already defined for it. // ";
        }
    }
}

# If returns False then destination type must not be used when composing namespace.
method derive-from-type(--> True) is pure {}

proto method preprocess-ns(::?CLASS:D: |) is raw {*}
multi method preprocess-ns(Bool:D $ns) is raw {
    return () unless $ns;
    (|($_ with .xml-default-ns), |($_ => True with .xml-default-ns-pfx)) given $!declarant.HOW
}
multi method preprocess-ns(NOT-SET) is raw {
    # When there is no explicit 'derive' directive and the declarant whants to impose its NS then it's the same as using
    # :ns
    self.preprocess-ns( !$!derive.defined && $!declarant.^xml-is-imposing-ns )
}
multi method preprocess-ns(Mu \ns) is raw { ns }

method infer-ns( ::?CLASS:D:
                   Mu :$from where { .WHAT =:= Nil || $_ ~~ $!declarant | LibXML::Node:D } = Nil,
                   # If set it would override what's provided by $from
                   Str :$default-ns,
                   # Same as with -ns
                   Str :$default-pfx )

{
    my (Str $namespace, Str $prefix) = ($.xml-default-ns, $.xml-default-ns-pfx);

    my $derive-forced := $!derive.defined;
    my $derive := $!derive // self.config-derive // False;

    without ($namespace // $prefix) {
        if $derive {
            # If derive is required either explicitly or implicitly, from config, then we either pick up namespace info:
            # - from a $resolve node where it is expected to be the final result of upstream serialization
            # - $from an xml-element instance where it might have been set manually by the user
            # - or $from a xml-element typeobject where we expect to find the defaults
            given $from {
                when LibXML::Node:D {
                    ($namespace, $prefix) = (.lookupNamespaceURI(""), .prefix);
                }
                when LibXML::Class::NS:D {
                    ($namespace, $prefix) = (.xml-default-ns // $default-ns, .xml-default-ns-pfx);
                }
                default {
                    my \typeobj = .WHAT =:= Nil ?? $.declarant !! $_;
                    ($namespace, $prefix) = ($default-ns // .xml-default-ns, $default-pfx // .xml-default-ns-pfx)
                        given (typeobj.HOW ~~ LibXML::Class::NS ?? typeobj.HOW !! typeobj.xml-class.HOW);
                }
            }
        }
        else {
            if (my \ntype = self.nominal-type) ~~ LibXML::Class::NS && self.derive-from-type {
                # If :derive is not set then try picking from destination type if it's an NS-kind
                ($namespace, $prefix) = (.xml-default-ns, .xml-default-ns-pfx) with ntype.xml-class.HOW;
            }

            without $namespace {
                # When :!derive is in effect make sure that "no explicit namespace" translates into "explicit no
                # namespace"
                if $derive-forced {
                    $namespace = "";
                }
            }
        }
    }

    ($namespace, $prefix)
}

method type-check(Mu \value, $when --> Mu) is raw {
    my \vtype = self.value-type;
    unless (value ~~ vtype) || (value ~~ Nil && !(vtype.^archetypes.definite && vtype.^definite)) {
        LibXML::Class::X::TypeCheck.new(
            :descriptor(self), :when($when ~~ Code ?? $when() !! $when.Str), :got(value), :expected(vtype)).throw
    }
    value
}

method has-serializer(::?CLASS:D:)        { &!serializer.defined }
method has-deserializer(::?CLASS:D:)      { &!deserializer.defined }
method serializer-cando(::?CLASS:D: |c)   { (&!serializer andthen .cando(c)) // False }
method deserializer-cando(::?CLASS:D: |c) { (&!deserializer andthen .cando(c)) // False }

# Copyright (c) 2023, Vadim Belman <vrurg@cpan.org>
#
# See the LICENSE file for the license