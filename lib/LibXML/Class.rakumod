use v6.e.PREVIEW;
unit module LibXML::Class;
use nqp;
use experimental :will-complain;

INIT {
    PROCESS::<$LIBXML-CLASS-CTX> := Nil;
}

use AttrX::Mooish:ver<1.0.0+>:api<1.0.0+>;
use Hash::Merge:ver<2.0.0>:auth<github:scriptkitties>:api<2>;
use LibXML:ver<0.10.0>;
use LibXML::Document;
use LibXML::Element;
use LibXML::Item;
use LibXML::Namespace;
use LibXML::Text;

use LibXML::Class::Attr;
use LibXML::Class::Config :types;
use LibXML::Class::CX;
use LibXML::Class::Document;
use LibXML::Class::HOW::Element;
use LibXML::Class::HOW::ElementRole;
use LibXML::Class::HOW::ElementSeq;
use LibXML::Class::ItemDescriptor;
use LibXML::Class::Node;
use LibXML::Class::NS;
use LibXML::Class::X;
use LibXML::Class::XML;
use LibXML::Class::Types :ALL;
use LibXML::Class::Utils;

role XMLRepresentation {...}
role XMLSequential {...}

my class DeserializingCtx does LibXML::Class::NS {
    has XMLRepresentation:U $.into is required;
    has XMLRepresentation:U $.into-xml-class = $!into.xml-class;
    has LibXML::Element:D $.elem is required;
    has LibXML::Class::Document:D $.document is required;
    has LibXML::Class::Config:D $.config = $!document.config;
    has LibXML::Node @.child-elems = $!elem.elements;
    has Map $!child-idx = @!child-elems.map(*.unique-key).antipairs.Map;
    has LibXML::Node @.attributes = $!elem.properties;
    has Map $!attr-idx = @!attributes.map(*.unique-key).antipairs.Map;
    # User input to from-xml method
    has %.user-profile;
    # The resulting profile
    has %.profile = :$!document;

    # Map namespace/node name into descriptor objects
    has %!xml-props;
    has %!xml-tags;
    has $.xml-text;

    submethod TWEAK {
        without %!profile<xml-namespaces> {
            %!profile<xml-namespaces> =
                |$!into-xml-class.HOW.xml-namespaces,
                |$!elem.namespaces.grep(*.declaredPrefix).map({ .declaredPrefix => .declaredURI });
        }

        # Build context-dependent mappings of namespace/XML node name into Raku class attribute objects
        for $!into.xml-class.^xml-attrs(:!local).values {
            when LibXML::Class::Attr::XMLAttribute {
                self!add-attribute($_, .xml-name, %!xml-props);
            }
            when LibXML::Class::Attr::XMLValueElement {
                self!add-attribute($_, .outer-name, %!xml-tags);
            }
            when LibXML::Class::Attr::XMLTextNode {
                LibXML::Class::X::AttrDuplication::Text.new(:type($!into), :attrs($!xml-text, $_)) if $!xml-text;
                $!xml-text = $_;
            }
            default {
                die "Don't know how to use attribute's { .name } object of type " ~ .^name;
            }
        }

        if $!into ~~ XMLSequential {
            for $!into-xml-class.^xml-all-item-descriptors -> LibXML::Class::ItemDescriptor:D $desc {
                self!add-seq-descriptor($desc)
            }
        }
    }

    # Resolve current context expected default namespace based on:
    # 1. default prefix if defined
    # 2. default namespace
    # 3. a fallback found by resolving empty prefix
    method default-ns {
        self.resolve-ns( $!xml-default-ns // .xml-default-ns,
                         $!xml-default-ns-pfx // .xml-default-ns-pfx,
                         $!xml-namespaces{""} // "" )
            given $!into-xml-class.HOW
    }

    # Get what a namespace resolves into for a particular entity given that prefix weigh upon default namespace
    method resolve-ns(Str $namespace, Str $prefix, Str:D $fallback-ns = "") {
        ($prefix
            andthen (
                $!xml-namespaces{$_}
                // fail LibXML::Class::X::NS::Prefix.new(
                    :$prefix,
                    :while("deserializing element <" ~ $.elem.localName ~ ">") )))
            // $namespace
            // $fallback-ns
    }

    method !add-tag(LibXML::Class::Descriptor:D $descriptor, $namespace is copy, $prefix, $name, %into is raw) {
        if $prefix {
            # Pick by prefix from the attribute if there is any defined
            ($namespace = $descriptor.xml-namespaces{$prefix} // $!xml-namespaces{$prefix})
                // LibXML::Class::X::NS::Prefix.new(
                    :what("type " ~ $!into.^name),
                    :while("resolving " ~ $descriptor.descriptor-kind),
                    :prefix($prefix) ).throw
        }

        without $namespace {
            # If we still don't know our namespace then it means it would be borrowed from the upstream xmlns=
            $namespace = $!xml-namespaces{""} // "";
        }

        with %into{$namespace}{$name} {
            # Some other attribute has already claimed this node under the same namespace
            LibXML::Class::X::Deserialize::DuplicateTag.new(
                :type($!into), :$namespace, :$name, :desc1($_), :desc2($descriptor) ).throw
        }
        %into{$namespace}{$name} = $descriptor;

        $namespace
    }

    method !add-attribute($attr, $name, %into is raw) {
        my ($namespace, $prefix) =
            $attr.compose-ns(
                :from($!into-xml-class),
                :default-ns($!xml-default-ns),
                :default-pfx($!xml-default-ns-pfx) );

        self!add-tag($attr, $namespace, $prefix, $name, %into);
    }

    method !add-seq-descriptor($desc) {
        my ($namespace, $prefix) =
            $desc.infer-ns( :from($!into-xml-class), :default-ns($!xml-default-ns), :default-pfx($!xml-default-ns-pfx) );

        unless my $name = $desc.xml-name {
            if $!into-xml-class.^xml-either-any {
                $name = .xml-name
                    with $.config.ns-map-type( $desc.type,
                                               :namespace(self.resolve-ns($namespace, $prefix)) );
            }
        }

        # No name means no way to resove this descriptor. This could be intentional, say, when a type is not supposed
        # to be used with sequence for a specific namespace.
        return unless $name;

        self!add-tag($desc, $namespace, $prefix, $name, %!xml-tags);
    }

    # attr-for- methods map a LibXML::Node into a LibXML::Class attribute based on the node namespace.
    # The matching NS is passed into &with callback for later use.
    method attr-for-prop(LibXML::Attr:D $desc) {
        my $namespace = $desc.namespaceURI // "";
        my $xml-name = $desc.name;
        (%!xml-props{$namespace} andthen .{$xml-name}) orelse Nil
    }

    method desc-for-elem(LibXML::Element:D $elem) {
        my $namespace = $elem.namespaceURI // "";
        my $elem-name = $elem.localname;
        (%!xml-tags{$namespace} andthen .{$elem-name}) orelse Nil
    }

    method unclaimed-children {
        @!child-elems.grep(*.defined)
    }

    method claim-child(LibXML::Node:D $elem, LibXML::Class::Attr::XMLish :$lazy-attr) {
        @!child-elems[$!child-idx{$elem.unique-key}]:delete;
    }

    method add-lazy(LibXML::Class::Attr::XMLish:D $lazy-attr, $initializer) {
        my $attr-name = $lazy-attr.name;
        # If the destination attribute is a positional we may expect more children to come later unless it is
        # containerized.
        if $lazy-attr ~~ LibXML::Class::Attr::XMLPositional {
            (%!profile<xml-lazies>{$attr-name} //= []).push: $initializer;
        }
        elsif $lazy-attr ~~ LibXML::Class::Attr::XMLTextNode {
            %!profile<xml-lazies>{$attr-name} = $initializer;
        }
        else {
            if %!profile<xml-lazies>{$attr-name}:exists {
                $!config.alert:
                    LibXML::Class::X::AttrDuplication::XMLNode.new(
                        :node-name($initializer.name),
                        :attr($lazy-attr),
                        :type($!into))
            }
            %!profile<xml-lazies>{$attr-name} := $initializer;
        }
    }

    method unclaimed-attrs {
        @!attributes.grep(*.defined)
    }

    method claim-attr(LibXML::Attr:D $attr) {
        @!attributes[$!attr-idx{$attr.unique-key}]:delete
    }

    proto method to-profile(|) {*}

    multi method to-profile(LibXML::Class::Attr::XMLish:D $attr, Mu \value, *%c --> Nil) {
        self.to-profile: $attr.name.substr(2), value, positional => ($attr ~~ LibXML::Class::Attr::XMLPositional), |%c, :$attr;
    }

    multi method to-profile(Str:D $pkey,
                            Mu \value,
                            LibXML::Node :$node,
                            Bool :$positional,
                            LibXML::Class::Attr::XMLish :$attr
        --> Nil)
    {
        if $positional {
            (%!profile{$pkey} // (%!profile{$pkey} := [])).push: value;
        }
        else {
            if $node && %!profile.EXISTS-KEY($pkey) {
                $!config.alert:
                    LibXML::Class::X::AttrDuplication::Node.new(:$node, :type($!into), :$attr)
            }
            %!profile{$pkey} := value;
        }
    }

    method final-profile(--> Hash:D) is raw {
        my @unclaimed-elems = self.unclaimed-children;
        my @unclaimed-attrs = self.unclaimed-attrs;

        if $!config.severity !== EASY && (@unclaimed-elems || @unclaimed-attrs) {
            my $ex = LibXML::Class::X::UnclaimedNodes.new(:$!elem, :unclaimed(|@unclaimed-elems,
                                                                              |@unclaimed-attrs));
            $ex.throw if $!config.severity == STRICT;
            warn $ex.message;
        }

        if (|@unclaimed-attrs.map(*.ast), |@unclaimed-elems.map(*.ast)).List -> $unused {
            %!profile<xml-unused> := $unused
        }
        # Preserve for lazy object creation. Could be optimized out at some point by analyzing if any laziness is
        # ever expected.
        %!profile<xml-user-profile> = %!user-profile;

        %!profile<xml-default-ns xml-default-ns-pfx> = $!xml-default-ns, $!xml-default-ns-pfx;

        %!profile<xml-default-ns-pfx xml-document> = $!elem.prefix, $!document;

        if %!profile<xml-seq-elems> || %!profile<xml-lazies> {
            %!profile<xml-backing> = $!elem;
            %!profile<xml-dctx> = self;
        }

        # Manually apply user profile to preserve key containerization.
        %!profile{$_} := %!user-profile{$_} for %!user-profile.keys;

        # Signal that the profile is an outcome of deserialization process.
        %!profile<XML-DESERIALIZED> = True;

        %!profile
    }
}

class XMLObject does LibXML::Class::Node {
    # Collection of AST nodes representing XML entities which do not have mapping into our class
    has $!xml-unused is mooish(:lazy(-> $, *% { [] }));

    # The XML elemnt this object has been initialized from. Only makes sense for lazies.
    has LibXML::Element $!xml-backing;

    # If there is any lazy then this is the context to use to deserialize them.
    has DeserializingCtx $!xml-dctx;

    # Attribute name -> child node index on this class' element
    has Associative $!xml-lazies;

    has LibXML::Class::Document $!xml-document;

    # What we've got as from-xml %profile argument
    has %!xml-user-profile;

    # Setup some attributes explicitly because keeping them private is beneficial in certain cases like testing by
    # comparing objects where content of these is irrelevant.
    submethod TWEAK( Positional :$!xml-unused,
                     LibXML::Element :$!xml-backing,
                     Associative :$!xml-lazies,
                     LibXML::Class::Document :$!xml-document,
                     DeserializingCtx :$!xml-dctx,
                     Bool:D :$XML-DESERIALIZED = False,
                     *%profile )
    {
        given self.xml-class.HOW {
            # Don't set namespace or prefix either if profile has been produced by deserialization; or if there is
            # user-provided value, even if it is undefined.
            unless $XML-DESERIALIZED {
                $!xml-default-ns //= .xml-default-ns unless %profile<xml-default-ns>:exists;
                $!xml-default-ns-pfx //= .xml-default-ns-pfx unless %profile<xml-default-ns-pfx>:exists;
            }
            # Defaults from HOW must not override what's set by the user. Deserialization might override these from
            # XML source.
            merge-in-namespaces(self.xml-namespaces, .xml-namespaces);
        }
    }

    method xml-config {
        $*LIBXML-CLASS-CONFIG // $!xml-document.config // LibXML::Class::Config.global
    }

    # For some purposes it's better for the attributes to remain private, see TWEAK's comment.
    method xml-unused(::?CLASS:D:)       is raw { $!xml-unused }
    method xml-backing(::?CLASS:D:)      is raw { $!xml-backing }
    method xml-lazies(::?CLASS:D:)       is raw { $!xml-lazies }
    method xml-document(::?CLASS:D:)     is raw { $!xml-document }
    method xml-user-profile(::?CLASS:D:) is raw { %!xml-user-profile }

    method xml-has-lazies(::?CLASS:D:) { ? $!xml-lazies }

    method xml-serialize-stages is raw {
        ('xml-to-element-repr',)
    }
    method xml-profile-stages is raw {
        ('xml-from-element-repr',)
    }

    # Overriding this method can help in using from-xml method to de-serialize into non-XMLObject classes. See, for
    # example, method xmlize of LibXML::Class::Config
    method xml-create(*%profile) {
        self.new: |%profile
    }

    method xml-create-child-element( ::?CLASS:D:
                                     LibXML::Element:D $parent,
                                     LibXML::Class::Node:D $from,
                                     Str :$name,
                                     *%profile
        --> LibXML::Element:D )
    {
        # By default we borrow parent element default namespace.
        my $child = $parent.ownerDocument.createElement($name // $from.xml-name);
        $parent.add: $child;
        $from.xml-apply-ns($child, |%profile);
        $child
    }

    proto method xml-type-from-str(Mu:U, Str:D) {*}
    multi method xml-type-from-str(Bool, Str:D $xml-value) {
        ($xml-value eq "1" | "true")
            or ($xml-value eq "0" | "false"
            ?? False
            !! LibXML::Class::X::Deserialize::BadValue.new(:type(Bool), :value($xml-value)).throw)
    }
    multi method xml-type-from-str(::T Mu:U, T(Str:D) \coerced) {
        coerced
    }

    proto method xml-type-to-str(|) {*}
    multi method xml-type-to-str(Bool:D \val) {
        val.Str.lc
    }
    # Make sure Num is still recognized as a Num by force-preserve the exponent part 'e' and trying to preserve all
    # fraction digits. Since there is no fully legitimate way to do it then we use a trick by printing more that it is
    # really necessary and then stripping off all tailing zeroes.
    multi method xml-type-to-str(Num:D \val) {
        S/^ $<significant>=[.* "." . .*?] 0* $<exponential>=[ e <[+-]>? \d+ ] $/$<significant>$<exponential>/
            with val.fmt('%.64e')
    }
    multi method xml-type-to-str(Mu:D \val where *.HOW ~~ Metamodel::EnumHOW) {
        ~val.value
    }
    multi method xml-type-to-str(Mu \val) {
        ~val
    }

    method xml-try-deserializer( LibXML::Class::Descriptor:D $desc,
                                 Mu $value is raw,
                                 &fallback?,
                                 Mu :$value-type is raw = NOT-SET,
                                 Bool:D :$coerce = True
        --> Mu) is raw
    {
        my Mu $rc;
        my \expect-type = $value-type =:= NOT-SET ?? $desc.value-type !! $value-type;

        # note "VALUE TYPE of ", $desc.descriptor-kind, " is ", expect-type.^name, "\n",
        #     "    deserializing from ", $value.WHICH, "\n",
        #     "    can deserialize? ", $desc.deserializer-cando($value);

        unless (my Bool $use-type-to-str = !$desc.deserializer-cando($value)) {
            $rc := try {
                CATCH { default { return .Failure } }
                CONTROL {
                    when LibXML::Class::CX::Cannot {
                        $use-type-to-str = True;
                    }
                    default { .rethrow }
                }
                $desc.deserializer.($value)
            }
        }

        if $use-type-to-str {
            $rc := &fallback
                    ?? &fallback()
                    !! $coerce
                        ?? self.xml-type-from-str: expect-type, $value
                        !! Nil;
        }

        $rc
    }

    # xml-coerce-into-attr always works on a single string or element. Any containerization, positionals are to be unwrapped
    # by the upstream. Since associatives are always single-elemented we do handle them in here.
    proto method xml-coerce-into-attr(LibXML::Class::Attr::XMLish:D, $) {*}

    multi method xml-coerce-into-attr(LibXML::Class::Attr::XMLAssociative:D $desc, LibXML::Element:D $elem) {
        my Mu \value-type = $desc.value-type;
        my Mu \key-type = $desc.type.keyof;

        my $value-attr = $desc.value-attr;
        my &mapper = $desc.has-deserializer
            ?? $value-attr
                ?? { self.xml-type-from-str(key-type, .localname)
                        => self.xml-try-deserializer($desc, .getAttribute($value-attr)) }
                !! { self.xml-type-from-str(key-type, .localname)
                        => self.xml-try-deserializer($desc, .textContent) }
            !! $value-attr
                ?? { self.xml-type-from-str(key-type, .localname)
                        => self.xml-type-from-str(value-type, .getAttribute($value-attr)) }
                !! { self.xml-type-from-str(key-type, .localname)
                        => self.xml-type-from-str(value-type, .textContent) };

        $elem.childNodes.map(&mapper).cache
    }

    multi method xml-coerce-into-attr(LibXML::Class::Attr::XMLValueElement:D $desc, LibXML::Element:D $elem) {
        # Deserializer of an element attribute takes the element. We wash our hands here.
        # note "? trying deserializer with ", $desc.descriptor-kind;
        my $not-deserialized = False;
        my Mu $value := self.xml-try-deserializer: $desc, $elem, :!coerce, {
            # This is a fallback when for any reason user deserializer hasn't produced a value.
            $not-deserialized = True;
        };
        # note "? not deserialized: ", $not-deserialized, ", value=", $value.raku;
        return $value unless $not-deserialized;

        my $dctx = $*LIBXML-CLASS-CTX;
        my $xml-config = $.xml-config;

        my Mu $desc-type;
        my Mu $value-type;
        my LibXML::Element:D $velem = $elem;
        my %named = :user-profile($dctx.user-profile);

        if $desc.is-any {
            $velem = $elem.elements.head;
            $desc-type := nominalize-type($value-type := $xml-config.ns-map($velem));
            if $desc-type =:= Nil {
                my $ex = LibXML::Class::X::Deserialize::NoNSMap.new(:type(self.WHAT), :elem($velem));
                $xml-config.alert: $ex;
                # Unless severity level is  STRICT then return a Failure. If that's ok with the user and their
                # destination container allows for it then that failure can be used by serialization to reproduce the
                # original element. Otherwise throwing due to failed typecheck would be a totally reasonable outcome.
                fail $ex
            }

            # Element name may differ from what's $desc-type default name is. Make sure it won't be a problem.
            %named<name> = $velem.localName;
        }
        else {
            $value-type := $desc.value-type<>;
            $desc-type := $desc.nominal-type<>;
            %named<name> = $desc.value-name;
        }

        unless $desc-type ~~ BasicType | XMLRepresentation {
            if $desc-type.^archetypes.composable {
                # If we got here then attribute's type is a role and there is no way to find out what class to
                # deserialize into.
                LibXML::Class::X::Deserialize::Role.new(:type(self.WHAT), :$desc).throw
            }
            $desc-type := $xml-config.xmlize($desc-type, XMLRepresentation);
        }

        # If destination type is an XMLRepresentation then let it deserialize itself
        if $desc-type ~~ XMLRepresentation {
            # Make sure prefixes declared with this attribute xml-element are propagaded downstream.
            my %*LIBXML-CLASS-NS-OVERRIDE = $desc.xml-namespaces;
            %named<namespace prefix> =
                $desc.compose-ns(:from(self), :default-ns($dctx.xml-default-ns), :default-pfx($dctx.xml-default-ns-pfx));
            return $desc-type.from-xml($velem, $dctx.document, |%named)
        }

        # Otherwise this is a case of a simple element where we need either its text content or value attribute.
        self.xml-try-deserializer: $desc, ($_ ?? $velem.getAttribute($_) !! $velem.textContent), :$value-type
            given $desc.value-attr
    }

    multi method xml-coerce-into-attr(LibXML::Class::Attr::XMLAttribute:D $desc, LibXML::Attr:D $xml-attr) {
        self.xml-try-deserializer: $desc, $xml-attr.value
    }

    multi method xml-coerce-into-attr(LibXML::Class::Attr::XMLTextNode:D $desc, Str:D $xml-value) {
        self.xml-try-deserializer: $desc, $xml-value
    }

    method xml-lazy-deserialize-context(&code, LibXML::Class::NS :$desc) is raw {
        my $*LIBXML-CLASS-CTX = $!xml-dctx;
        my $*LIBXML-CLASS-CONFIG = $!xml-dctx.document.config;
        # Where there is no more lazies to deserialize we don't need the context object anymore.
        LEAVE { $!xml-dctx = Nil unless self.xml-has-lazies }
        &code()
    }

    # This method is to be used as the builder for lazy attributes.
    proto method xml-deserialize-attr(::?CLASS:D: |) {*}

    # This candidate would basically serve as the entry point because $attribute is always passed in by AttrX::Mooish
    multi method xml-deserialize-attr(::?CLASS:D: Str:D :$attribute!) {
        self.xml-deserialize-attr: $attribute, self.^xml-get-attr($attribute)
    }

    multi method xml-deserialize-attr(::?CLASS:D: Str:D $attr-name, LibXML::Class::Attr::XMLPositional:D $attr) {
        with $!xml-lazies{$attr-name} -> \initializer {
            return self.xml-lazy-deserialize-context: :desc($attr), {
                # Map creates a lazy Seq where map's code is invoked under another stack frame than this one thus
                # effectively loosing the dynamic context and all $*LIBXML-CLASS variables. .eager forces it to be
                # executed in place.
                initializer.map({
                    $attr.type-check:
                        self.xml-coerce-into-attr($attr, $_),
                        # Use code to postpone message generation until really needed
                        { "while deserializing " ~ brief-elem-str($_) }
                }).eager
            }
        }
        Empty
    }

    multi method xml-deserialize-attr(::?CLASS:D: Str:D $attr-name, LibXML::Class::Attr::XMLish:D $attr) {
        my Mu $value := Nil;
        with $!xml-lazies{$attr-name} -> \initializer {
            self.xml-lazy-deserialize-context: :desc($attr), {
                $value := self.xml-coerce-into-attr($attr, initializer);
            }
        }
        $attr.type-check:
            $value,
            # Use code to postpone message generation until really needed
            { "while deserializing " ~ brief-elem-str($!xml-backing) }
    }

    method xml-decontainerize(LibXML::Element:D $elem,
                              LibXML::Class::Attr::XMLContainer:D $attr,
                              Str:D $expected-ns = $elem.namespaceURI // "",
                              # Should we throw away empty #text?
                              Bool :$trim
        --> Iterable:D)
    {
        return ($elem,) unless $attr.container;

        # If we got here it means the container element has been validated already and matches NS and container name
        # of the attribute $attr
        gather {
            for $elem.children -> LibXML::Node:D $child {
                if $child ~~ LibXML::Text {
                    next if $trim && !$child.data.trim;
                    take $child;
                }
                else {
                    if (my $childNS = $child.namespaceURI // "") ne $expected-ns {
                        # Mismatch of container's child element to the expected namespace is not ignorable.
                        LibXML::Class::X::NS::Mismatch.new(
                            :expected($expected-ns),
                            :got($childNS),
                            :what("child element '" ~ $child.name ~ "' of container '" ~ $elem.name ~ "'")).throw
                    }
                    take $child
                }
            }
        }
    }

    # Serialize a value based on attribute meta data.
    method xml-ser-desc-value(LibXML::Class::Descriptor:D $desc, Mu $value is raw --> Str:D) {
        ($desc.serializer andthen .cando($value))
            ?? $desc.serializer.($value)
            !! self.xml-type-to-str($value)
    }

    method xml-ser-desc-val2elem(LibXML::Element:D $velem, LibXML::Class::Descriptor:D $desc, Mu $value) {
        my $*LIBXML-CLASS-ELEMENT = $velem;

        if ($desc.serializer andthen .cando($velem, $value)) {
            $desc.serializer.($velem, $value);
        }
        else {
            if $desc.value-attr -> $xml-aname {
                # Attribute value is to be kept in XML element attribute
                $velem.setAttribute($xml-aname, self.xml-ser-desc-value($desc, $value))
            }
            elsif !($desc.serializer andthen $desc.serializer.cando($value))
                && ($value ~~ XMLRepresentation || $value !~~ BasicType)
            {
                my $cvalue = $value;
                unless $cvalue ~~ XMLRepresentation {
                    # Turn a basic class into an XMLRepresentation with implicit flag raised
                    $cvalue = $.xml-config.xmlize($value, XMLRepresentation);
                }
                # TODO Attribute xml-namespace is not used; set element namespace if attribute overrides it.
                $cvalue.to-xml($velem);
            }
            else {
                $velem.appendText(self.xml-ser-desc-value($desc, $value));
            }
        }
    }

    # Take a dummy XML element and complete it with data from attribute value.
    method xml-ser-attr-val2elem( LibXML::Element:D $elem,
                                  LibXML::Class::Attr::XMLish:D $desc,
                                  Mu $value )
    {
        my LibXML::Element:D $velem = $elem;

        if $desc.is-any {
            my $xml-config = $.xml-config;

            # When attribute value is an xml-element then let it do all the work, but prepare an element for it first
            # so that if it refers to upstream xmlns prefixes then it will have them readily available.

            # Map through configuration's ns-map first.
            my $ns = $elem.namespaceURI // "";
            without my $ns-map = $xml-config.ns-map-type($value.WHAT, :$ns) {
                $xml-config.alert:
                    LibXML::Class::X::Serialize::Impossible.new(
                        :type(self.WHAT),
                        :what($value),
                        :why( "not found in config's ns-map for attribute "
                                ~ $desc.name
                                ~ " with namespace '$ns'" ));
                return Nil
            }

            $velem = self.xml-create-child-element:
                        $elem,
                        ($value ~~ XMLRepresentation ?? $value !! $desc),
                        :name($ns-map.xml-name),
                        # only take attribute's element prefix if set. Namespace would be irrelevant since it would be
                        # just borrowed in the absense of the prefix. This only works for XML:any-sourced elements.
                        |(:prefix($_) with $elem.prefix);
        }

        self.xml-ser-desc-val2elem($velem, $desc, $value);
        $elem
    }

    proto method xml-serialize-attr(LibXML::Element:D, LibXML::Class::Attr::XMLish:D) {*}

    multi method xml-serialize-attr(LibXML::Element:D $elem, LibXML::Class::Attr::XMLAttribute:D $desc) {
        my $value := $desc.attr.get_value(self);

        return without $value;

        my $xml-attr-name = $desc.xml-name;
        my $xml-attr-value = self.xml-ser-desc-value($desc, $value);

        my ($ns, $) = $desc.compose-ns(:from($elem), :resolve);

        with $ns {
            $elem.setAttributeNS: $ns, $xml-attr-name, $xml-attr-value;
        }
        else {
            $elem.setAttribute: $xml-attr-name, $xml-attr-value;
        }
    }

    multi method xml-serialize-attr(LibXML::Element:D $elem, LibXML::Class::Attr::XMLTextNode:D $desc) {
        with $desc.get_value(self) {
            $elem.appendText: self.xml-ser-desc-value($desc, $_);
        }
    }

    multi method xml-serialize-attr(LibXML::Element:D $elem, LibXML::Class::Attr::XMLPositional:D $desc) {
        my @attr-values = $desc.get_value(self);

        return unless @attr-values;

        # Positional containerization differs from other elements since by default their elements are direct
        # children of the parent.
        my ($namespace, $prefix) = $desc.compose-ns(:from($elem));

        my LibXML::Element:D $celem =
            $desc.container
                ?? self.xml-create-child-element($elem, $desc, :name($desc.container-name), :$namespace, :$prefix)
                !! $elem;

        for @attr-values -> $avalue {
            my $velem =
                self.xml-create-child-element($celem, $desc, :name($desc.value-name($avalue)), :$namespace, :$prefix);
            self.xml-ser-attr-val2elem: $velem, $desc, $avalue;
        }
    }

    multi method xml-serialize-attr(LibXML::Element:D $elem, LibXML::Class::Attr::XMLAssociative:D $desc) {
        my %attr-values = $desc.get_value(self);

        return unless %attr-values;

        my $document = $elem.ownerDocument;

        my ($namespace, $prefix) = $desc.compose-ns(:from($elem));
        my $celem = self.xml-create-child-element($elem, $desc, :$namespace, :$prefix);

        $desc.xml-apply-ns($celem, :$namespace, :$prefix);

        for %attr-values.sort -> (:key($vname), :$value) {
            my LibXML::Element:D $velem =
                self.xml-create-child-element($celem, $desc, :name($vname), :$namespace, :$prefix);
            self.xml-ser-attr-val2elem: $velem, $desc, $value;
        }
    }

    multi method xml-serialize-attr(LibXML::Element:D $elem, LibXML::Class::Attr::XMLValueElement:D $desc) {
        my $value := $desc.get_value(self);

        return without $value;

        my $document = $elem.ownerDocument;
        my $attr-type := $desc.nominal-type<>;

        my (Str $namespace, Str $prefix) = $desc.compose-ns(:from($elem));

        my LibXML::Element:D $celem =
            $desc.container
                ?? self.xml-create-child-element($elem, $desc, :name($desc.container-name), :$namespace, :$prefix)
                !! $elem;

        my LibXML::Element:D $attr-elem =
            self.xml-create-child-element($celem, $desc, :name($desc.value-name($value)), :$namespace, :$prefix);

        self.xml-ser-attr-val2elem: $attr-elem, $desc, $value;
    }

    method xml-to-element-repr(LibXML::Element:D $elem) {
        for self.^xml-attrs(:!local).values -> LibXML::Class::Attr::XMLish:D $desc {
            self.xml-serialize-attr($elem, $desc)
        }
    }

    method xml-to-element( ::?CLASS:D:
                           LibXML::Element:D $elem,
                           Str :ns(:xml-default-ns(:$namespace)),
                           Str :xml-default-ns-pfx(:$prefix)
        --> LibXML::Element:D ) is implementation-detail
    {
        self.xml-apply-ns( $elem, :$namespace, :$prefix,
                           # Don't override default namespace and prefix if any of them is already set.
                           default => (! ($elem.prefix // $elem.namespaceURI).defined) );

        $.xml-unused andthen .map: -> $ast {
            given LibXML::Item.ast-to-xml($ast) {
                when LibXML::Attr {
                    $elem.setAttributeNode($_);
                }
                default {
                    $elem.add: $_
                }
            }
        }

        # Process all our XML attributes
        for self.xml-serialize-stages -> $stage {
            self."$stage"($elem);
        }

        $elem
    }

    method xml-new-dctx(*%profile) {
        DeserializingCtx.new: |%profile
    }

    method xml-from-element( LibXML::Element:D $elem,
                             LibXML::Class::Document:D $doc,
                             :%user-profile,
                             Str :$name,
                             Str :namespace(:ns(:$xml-default-ns)) is copy,
                             Str :prefix(:$xml-default-ns-pfx) is copy )
    {
        my $how = self.xml-class.HOW;

        my $ctx-outer := $*LIBXML-CLASS-CTX || Nil;

        # Merge namespace prefixes.
        my %xml-namespaces is OHash =
            |(.xml-namespaces with $ctx-outer),
            |$how.xml-namespaces,
            |("" => $_ with ($xml-default-ns // $how.xml-default-ns)),
            |(%*LIBXML-CLASS-NS-OVERRIDE || ());

        my \xml-class-how = self.xml-class.HOW;
        # When there is no explicit default namespaces we do fallback to the outer default. But not for the prefix
        # which is not inherited by a prefix-less XML entity from its parent.
        $xml-default-ns //= xml-class-how.xml-default-ns // ($ctx-outer andthen .xml-default-ns orelse Nil);
        $xml-default-ns-pfx //= xml-class-how.xml-default-ns-pfx;

        my $dctx =
            self.xml-new-dctx:
                :into(self.WHAT), :$elem, :document($doc),
                :%user-profile, :%xml-namespaces,
                :$xml-default-ns, :$xml-default-ns-pfx;

        {
            my $*LIBXML-CLASS-CTX = $dctx;
            my $*LIBXML-CLASS-CONFIG = $dctx.document.config;

            # Make sure first we can deserialize from this element
            my Str $default-ns = $dctx.default-ns;
            my Str:D $expect-name = $name // $.xml-name;
            unless ($elem.localName eq $expect-name) && ($elem.namespaceURI // "") ~~ $default-ns {
                $.xml-config.alert:
                    LibXML::Class::X::Deserialize::BadNode.new(
                        :type(self.WHAT),
                        :expected("<" ~ $expect-name ~ "> XML tag" ~ (" in namespace '$_'" with $default-ns)),
                        :got("<" ~ $elem.localName ~ ">" ~ (" in namespace '$_'" with $elem.namespaceURI)) );
                # If we are not in STRICT severity mode then return nothing
                return Nil;
            }

            for self.xml-profile-stages -> $stage {
                self."$stage"($dctx);
            }
        }

        {
            CATCH {
                default {
                    LibXML::Class::X::Deserialize::New.new( :type(self.WHAT), :exception($_), :$elem ).throw
                }
            }
            self.xml-create: |$dctx.final-profile
        }
    }

    method clone-from(Mu:D $obj) {
        my %profile;
        for $obj.^attributes(:!local).grep({ .has_accessor || .is_built }) -> Attribute:D $attr {
            %profile{$attr.name.substr(2)} := $attr.get_value($obj);
        }
        self.new: |%profile
    }

    proto method xml-config-context(|) {*}
    multi method xml-config-context(&code, LibXML::Class::Document:D :$document, *%twiddles) is raw {
        self.xml-config-context: &code, :config($document.config), |%twiddles;
    }
    multi method xml-config-context(&code, LibXML::Class::Config:D :$config, *%twiddles) is raw {
        &code( my $*LIBXML-CLASS-CONFIG = %twiddles ?? $config.clone(|%twiddles) !! $config )
    }
    multi method xml-config-context(&code, LibXML::Class::Document :$document, :%config, *%twiddles) {
        my $config =
            ((CALLERS::<$*LIBXML-CLASS-CONFIG>:exists
                ?? CALLERS::<$*LIBXML-CLASS-CONFIG>
                !! ($document andthen .config))
            andthen (%config || %twiddles ?? .clone(|%config, |%twiddles) !! $_)
            orelse LibXML::Class::Config.new(|self.xml-config-defaults, |%config, |%twiddles));

        my $*LIBXML-CLASS-CONFIG = $config;

        &code($config)
    }
    multi method xml-config-context(:$config, |c) {
        self.xml-config-context(|c, config => %$config)
    }

    proto method from-xml(|) {*}

    multi method from-xml( Str:D $source-xml,
                           Str :$name,
                           Str :ns(:namespace(:$xml-default-ns)),
                           Str :prefix(:$xml-default-ns-pfx),
                           :$config,
                           :%user-profile )
    {
        self.xml-config-context: :$config, {
            my LibXML::Class::Document:D $document .= parse: $source-xml, :config($_);
            self.from-xml:
                $document.libxml-document.documentElement,
                $document,
                :$name,
                :$xml-default-ns,
                :$xml-default-ns-pfx,
                :%user-profile
        }
    }

    multi method from-xml( Str:D $source-xml,
                           LibXML::Class::Document:D :$document!,
                           Str :$name,
                           Str :ns(:namespace(:$xml-default-ns)),
                           Str :prefix(:$xml-default-ns-pfx),
                           :%user-profile )
    {
        $document.parse(string => $source-xml);
        self.from-xml:
            $document.libxml-document.documentElement,
            $document,
            :$name,
            :$xml-default-ns,
            :$xml-default-ns-pfx,
            :%user-profile
    }

    multi method from-xml( LibXML::Document:D $libxml-document,
                           LibXML::Class::Config:D :$config!,
                           Str :$name,
                           Str :ns(:namespace(:$xml-default-ns)),
                           Str :prefix(:$xml-default-ns-pfx),
                           :%user-profile )
    {
        my LibXML::Class::Document:D $new-doc .= new: :$config, :$libxml-document;
        self.from-xml:
            $libxml-document.documentElement,
            $new-doc,
            :$name,
            :$xml-default-ns,
            :$xml-default-ns-pfx,
            :%user-profile
    }

    multi method from-xml( LibXML::Element:D $elem,
                           LibXML::Class::Document:D $document,
                           Str :$name,
                           Str :ns(:namespace(:$xml-default-ns)),
                           Str :prefix(:$xml-default-ns-pfx),
                           :%user-profile )
    {
        self.xml-config-context: :$document, {
            self.xml-from-element($elem, $document, :%user-profile, :$name, :$xml-default-ns, :$xml-default-ns-pfx)
        }
    }

    multi method from-xml( LibXML::Element:D $elem,
                           LibXML::Class::Document:U $?,
                           Str :$name,
                           Str :ns(:namespace(:$xml-default-ns)),
                           Str :prefix(:$xml-default-ns-pfx),
                           :$config,
                           :%user-profile )
    {
        my LibXML::Document:D $libxml-document = $elem.ownerDocument;
        self.xml-config-context: :$config, :libxml-config($libxml-document.config), {
            self.xml-from-element:
                $elem,
                .document-class.new(:$libxml-document, :config($_)),
                :%user-profile,
                :$name,
                :$xml-default-ns,
                :$xml-default-ns-pfx;
        }
    }

    proto method to-xml(::?CLASS:D: |) {*}

    multi method to-xml( ::?CLASS:D:
                         Str :$name,
                         Str :ns(:namespace(:$xml-default-ns)),
                         Str :prefix(:$xml-default-ns-pfx),
                         :$config )
    {
        self.xml-config-context: :$config, {
            my LibXML::Document:D $doc .= new(:config(.libxml-config));
            $doc.documentElement = samewith($doc, :$name, :$xml-default-ns, :$xml-default-ns-pfx);
            $doc
        }
    }

    multi method to-xml( ::?CLASS:D:
                         LibXML::Document:D $doc,
                         Str :$name,
                         Str :ns(:namespace(:$xml-default-ns)),
                         Str :prefix(:$xml-default-ns-pfx),
                         :$config )
    {
        self.xml-config-context: :$config, {
            my $elem = $doc.createElement($name // $.xml-name);
            self.xml-to-element($elem, :$xml-default-ns, :$xml-default-ns-pfx)
        }
    }

    multi method to-xml( ::?CLASS:D:
                         LibXML::Element:D $elem,
                         Str :ns(:namespace(:$xml-default-ns)),
                         Str :prefix(:$xml-default-ns-pfx),
                         :$config )
    {
        self.xml-config-context: :$config, {
            self.xml-to-element($elem, :$xml-default-ns, :$xml-default-ns-pfx)
        }
    }
}

our role XMLRepresentation does LibXML::Class::XML is XMLObject {
    method xml-build-name {
        (::?CLASS.^xml-name if ::?CLASS.HOW ~~ LibXML::Class::HOW::Element) // ::?CLASS.^shortname
    }

    proto method xml-name {*}
    multi method xml-name(::?CLASS:U:) { self.xml-build-name }
    multi method xml-name(::?CLASS:D:) { nextsame }

    method xml-config-defaults {
        ::?CLASS.^xml-config-defaults
    }

    # Since the actual xml-element class can be subclassed this method is fast and reliable way to know the innermost
    # xml-element parent of the subclass which will be in charge of serializing the object.
    method xml-class { ::?CLASS }

    method xml-from-element-repr(DeserializingCtx:D $dctx) {
        callsame();

        my $config = $dctx.config;
        my $lazy-class = ::?CLASS.^xml-is-lazy;
        my $force-eager = $config.eager;

        for $dctx.unclaimed-attrs -> LibXML::Attr:D $xml-attr {
            with $dctx.attr-for-prop($xml-attr) -> LibXML::Class::Attr::XMLAttribute:D $desc {
                if !$force-eager && ($desc.lazy // $lazy-class) {
                    $dctx.add-lazy($desc, $xml-attr);
                }
                else {
                    $dctx.to-profile:
                        $desc,
                        self.xml-coerce-into-attr($desc, $xml-attr),
                        :node($xml-attr);
                }

                $dctx.claim-attr($xml-attr);
            }
        }

        for $dctx.unclaimed-children -> LibXML::Element:D $elem {
            with $dctx.desc-for-elem($elem) -> LibXML::Class::Attr::XMLish:D $attr {
                my $value-elems := self.xml-decontainerize($elem, $attr, :trim);

                # Validate xml:any by making sure the number of XML elements matches attribute declaration.
                if $attr.is-any {
                    if $attr.sigil ne '@' {
                        $dctx.config.alarm:
                            LibXML::Class::X::Deserialize::BadNode.new(
                                :expected("single element for xml:any attribute " ~ $attr.name),
                                :got($value-elems.elems))
                            if $value-elems.elems > 1;
                    }
                    else {
                        for $value-elems.List -> $velem {
                            if $velem.elements.elems > 1 {
                                $dctx.config.alarm:
                                    LibXML::Class::X::Deserialize::BadNode.new(
                                        :type(self.WHAT),
                                        :expected("single child under xml:any element '" ~ $velem.name ~ "'"),
                                        :got($velem.elements.elems))
                            }
                        }
                    }
                }

                if !$force-eager && ($attr.lazy // $lazy-class) {
                    # Lazy xml-element attribute
                    for $value-elems {
                        $dctx.add-lazy($attr, $_);
                    }
                }
                else {
                    for $value-elems {
                        if $_ ~~ LibXML::Element {
                            $dctx.to-profile: $attr, self.xml-coerce-into-attr($attr, $_), :node($elem);
                        }
                        else {
                            $dctx.config.alert:
                                LibXML::Class::X::Deserialize::BadNode.new(
                                    :type(self.WHAT)
                                    :expected('an element'),
                                    :got('a ' ~ .^name ~ ' node'));
                        }
                    }
                }

                $dctx.claim-child($elem);
            }
        }

        with $dctx.xml-text {
            my $text-content = $dctx.elem.textContent.trim;
            $text-content .= trim if .trim;

            if !$force-eager && (.lazy // $lazy-class) {
                $dctx.add-lazy($_, $text-content)
            }
            else {
                $dctx.to-profile: $_, self.xml-coerce-into-attr($_, $text-content);
            }
        }
    }
}

# XMLSequence class is an implementation of xsd:sequence
class XMLSequence does Positional does Iterable {
    # Un-deserialized yet elements
    has @!xml-seq-elems is built;
    # Deserialized or user-installed items.
    has @!xml-items handles <ASSIGN-POS push append of>;

    # Whether we, or any of our parent class, or any role is an xml-any sequence. In other words, would we expect items
    # of a non-xml-element type?
    has Bool:D $.xml-is-any = self.xml-seq-either-any;

    multi method new(*@items, *%profile) {
        given self.bless(|%profile) {
            .append: @items;
            $_
        }
    }

    submethod TWEAK {
        @!xml-items := self.xml-seq-array-type.new;
        # Now we need to setup a container descriptor with name because by default a typed Array use no name causing
        # unclear type check error messages. This could be done with Metamodel, but nqp is faster because we delegate
        # the work of locating attributes to the backend.
        nqp::bindattr(@!xml-items, Array, '$!descriptor',
                      ContainerDescriptor.new(:name('item of <' ~ self.xml-name ~ '>'), :of(@!xml-items.of),
                                              :default(Any)));
    }

    method xml-has-lazies(::?CLASS:D:) {
        ?@!xml-seq-elems || nextsame()
    }

    method xml-serialize-stages is raw {
        <xml-to-element-repr xml-to-element-seq>
    }
    method xml-profile-stages is raw {
        <xml-from-element-seq xml-from-element-repr>
    }

    method xml-from-element-seq(DeserializingCtx:D $dctx) {
        my $xml-config = $dctx.config;
        my $of-type := self.of;

        for $dctx.unclaimed-children -> LibXML::Element:D $elem {
            if $dctx.desc-for-elem($elem) ~~ LibXML::Class::ItemDescriptor:D
                or (self.xml-seq-either-any
                    # If xml:any then tag must be in the namespace map and match an allowed item type
                    && (my \any-type = $xml-config.ns-map($elem)) !=== Nil
                    && any-type ~~ $of-type)
            {
                $dctx.to-profile('xml-seq-elems', $elem, :positional);
                $dctx.claim-child($elem);
            }
        }
    }

    method !xml-ser-guess-descriptor(LibXML::Element:D $elem, Mu $item) {
        my @desc = |self.xml-seq-desc-for-type($item);
        my Str $elem-ns = $elem.namespaceURI;

        if @desc > 1 {
            @desc = @desc.grep({ $elem-ns ~~ $^desc.ns });
        }

        my $xml-config = $.xml-config;

        if !@desc {
            $xml-config.alert:
                LibXML::Class::X::Serialize::Impossible.new(
                    :type(self.WHAT),
                    :what($item),
                    :why('the type is not registered with <' ~ $elem.localName ~ '>'));
            return Nil;
        }
        elsif @desc > 1 {
            $xml-config.alert:
                LibXML::Class::X::Serialize::Impossible.new(
                    :type(self.WHAT),
                    :what($item),
                    :why('too many declarations found for the type registered with <' ~ $elem.localName ~ '>'));
            return Nil
        }

        my LibXML::Class::ItemDescriptor:D $desc = @desc.head;

        return $desc if $desc.xml-name;

        # This object cannot carry objects of types not registered with specific XML names.
        unless self.xml-seq-either-any {
            $xml-config.alert:
                LibXML::Class::X::Serialize::Impossible.new(
                    :type(self.WHAT),
                    :what($item),
                    :why('<' ~ $elem.localName ~ '> is not xml-any, but the type has no associated name'));
            return Nil
        }

        # If the descriptor found doesn't have xml-name then it was a bare type registered with XML:any. We'd
        # need to pull the name with config's .ns-map.
        my $ns = $desc.xml-guess-default-ns(:resolve($elem)) // $elem.namespaceURI // "";
        without my $ns-map = $xml-config.ns-map-type($item.WHAT, :$ns) {
            $xml-config.alert:
                LibXML::Class::X::Serialize::Impossible.new(
                    :type(self.WHAT),
                    :what($item),
                    :why("no XML name found in config's ns-map for sequential <" ~ $elem.localName ~ "> and namespace '$ns'"));
            return Nil
        }

        $desc.clone: :xml-default-ns($ns), :xml-name($ns-map.xml-name)
    }

    method xml-create-item-element( ::?CLASS:D:
                                    LibXML::Element:D $parent,
                                    LibXML::Class::ItemDescriptor:D $desc )
    {
        my (Str $namespace, Str $prefix) = $desc.infer-ns(:from($parent));
        self.xml-create-child-element($parent, $desc, |(:name($_) with $desc.xml-name), :$namespace, :$prefix)
    }

    method xml-serialize-item(LibXML::Element:D $elem, LibXML::Class::ItemDescriptor:D $desc, Mu $value) {
        my LibXML::Element:D $item-elem = self.xml-create-item-element($elem, $desc);
        my $*LIBXML-CLASS-ELEMENT = $item-elem;
        self.xml-ser-desc-val2elem($item-elem, $desc, $value);
        $item-elem
    }

    method xml-to-element-seq(LibXML::Element:D $elem) {
        my Iterator:D $iter = self.iterator;
        my $xml-config = $.xml-config;
        loop {
            last if (my Mu $item := $iter.pull-one) =:= IterationEnd;

            my LibXML::Class::ItemDescriptor $desc = self!xml-ser-guess-descriptor($elem, $item);
            with $desc {
                my $*LIBXML-CLASS-DESCRIPTOR = $desc;
                self.xml-serialize-item($elem, $desc, $item);
            }
            else {
                $xml-config.alert:
                    LibXML::Class::X::Serialize::Impossible.new( :type(self.WHAT),
                                                                 :what($item),
                                                                 :why("no known serialization method"));
            }
        }
    }

    method xml-deserialize-item( ::?CLASS:D:
                                 LibXML::Class::ItemDescriptor:D $desc,
                                 LibXML::Element:D $elem,
                                 UInt:D :$index,
                                 DeserializingCtx:D :$dctx = $*LIBXML-CLASS-CTX ) is raw
    {
        self.xml-try-deserializer: $desc, $elem, :!coerce, {
            # For whatever reason, deserializer hasn't produced a value. Do it the standard way then.
            my Mu $item-type := $desc.value-type;

            if $item-type ~~ XMLObject {
                # Make sure prefixes declared on this item descriptor are propagaded downstream.
                my %*LIBXML-CLASS-NS-OVERRIDE = $desc.xml-namespaces;
                my ($namespace, $prefix) =
                    $desc.infer-ns(:from(self), :default-ns($dctx.xml-default-ns), :default-pfx($dctx.xml-default-ns-pfx));
                return $item-type.from-xml( $elem,
                                        $.xml-document,
                                        :name($desc.xml-name),
                                        :$namespace,
                                        :$prefix,
                                        user-profile => $dctx.user-profile )
            }
            self.xml-try-deserializer: $desc, ($_ ?? $elem.getAttribute($_) !! $elem.textContent)
                given $desc.value-attr
        }
    }

    method AT-POS(::?CLASS:D: $idx --> Mu) is raw {
        return @!xml-items[$idx] if @!xml-items[$idx]:exists;
        fail X::OutOfRange(:what<Index>, :got($idx), :range(0 .. self.end)) if $idx > self.end;

        # Item is not ready, deserialize corresponding element
        my LibXML::Element:D $elem = @!xml-seq-elems[$idx];
        without my LibXML::Class::ItemDescriptor $desc =
                    self.xml-lazy-deserialize-context: { $*LIBXML-CLASS-CTX.desc-for-elem($elem) }
        {
            LibXML::Class::X::Deserialize::UnknownTag.new(:type(self.WHAT), :xml-name($elem.localName)).throw
        }


        self.xml-lazy-deserialize-context: :$desc, {
            if !$desc && $!xml-is-any {
                unless (my \item-type = $*LIBXML-CLASS-CONFIG.ns-map($elem)) =:= Nil {
                    # When succeed in mapping an element into a type for xml-any try to go back to the registry and locate
                    # a descriptor for the type.
                    $desc = self!xml-ser-guess-descriptor($elem, item-type);
                }
            }

            without $desc {
                # TODO Give this a dedicated exception
                # If there is no descriptor at this point it means there is a serious problem on our hands since the
                # early processing should've filtered out any non-item elements.
                LibXML::Class::X::AdHoc.new(
                    message => "No type for sequential element <" ~ $elem.name ~ "> – how is it ever possible?").throw
            }

            @!xml-seq-elems[$idx]:delete;

            self.xml-deserialize-item($desc, $elem, :index($idx))
        }
    }

    method EXISTS-POS(::?CLASS:D: Int:D $pos) {
        $pos < @!xml-seq-elems || @!xml-items.EXISTS-POS($pos)
    }

    method elems {
        @!xml-seq-elems.elems max @!xml-items.elems
    }

    method end {
        @!xml-seq-elems.end max @!xml-items.end
    }

    multi method iterator(::?CLASS:D:) {
        class :: does Iterator {
            has $.idx = 0;
            has $.seq;

            method pull-one is raw {
                return IterationEnd if $!idx > $.seq.end;
                $.seq.AT-POS($!idx++)
            }
        }.new(:seq(self))
    }
    multi method iterator(::?CLASS:U:) {
        (self,).iterator
    }
}

our role XMLSequential does XMLRepresentation is XMLSequence {
    method of { ::?CLASS.^xml-array-type.of }
    method xml-seq-array-type { ::?CLASS.^xml-array-type }
    method xml-seq-either-any { ::?CLASS.^xml-either-any }
    method xml-seq-desc-for-type(Mu $item) { ::?CLASS.^xml-desc-for-type($item) }
}

BEGIN {
    my sub typeobj-as-sequence(Mu:U \typeobj, $sequence, Mu $any is raw) {
        my \child-types = $sequence.List;
        LibXML::Class::X::Sequence::NoItemDesc.new(:type(typeobj)).throw unless child-types.elems;

        my proto sub validate-args(Capture:D) {*}
        multi sub validate-args(
            $ ( Mu:U $type,
                Str :attr(:$value-attr),
                :namespace(:$ns) is copy,
                :&serializer,
                :&deserializer,
                Bool :$derive,
                *%c))
        {
            if %c {
                my $sfx = %c > 1 ?? "s" !! "";
                LibXML::Class::X::Trait::Argument.new(
                    :trait-name<xml-element>,
                    :why("unexpected named argument$sfx passed to :sequence of 'xml-element' trait: "
                        ~ %c.keys.sort.join(", "))).throw;
            }
            \(:$type, :$value-attr, :$derive, :&serializer, :&deserializer, |(:$ns with $ns))
        }
        multi sub validate-args($ (*%)) {
            LibXML::Class::X::Trait::Argument.new(
                :trait-name<xml-element>,
                :why(':sequence requires a type object')).throw
        }
        multi sub validate-args($ (Mu:D $p, *%)) {
            LibXML::Class::X::Trait::Argument.new(
                :trait-name<xml-element>,
                :why(':sequence requires a type object, not an instance of ' ~ $p.^name)).throw
        }
        multi sub validate-args($ (*@, *%)) {
            LibXML::Class::X::Trait::Argument.new(
                :trait-name<xml-element>,
                :why(':sequence only takes a single type object')).throw
        }

        my %std = :seq-how(typeobj.HOW), :declarant($*PACKAGE);
        my @item-desc;

        for child-types -> \ctype {
            my LibXML::Class::ItemDescriptor $child-desc;
            given ctype {
                when Pair:D {
                    # The order of constructor arguments is important here as client must be able to override the
                    # default naemspace, for example. And, yet, must not be able to use xml-name, not even by accident.
                    @item-desc.push:
                        LibXML::Class::ItemDescriptor.new(
                            |validate-args(.value.List.Capture),
                            :xml-name(.key),
                            |%std );
                }
                when Positional:D {
                    # Item declared as (XMLElementType, :ns(...))
                    @item-desc.push:
                        LibXML::Class::ItemDescriptor.new(
                            |validate-args(.List.Capture), |%std );
                }
                when Mu:U {
                    if $_ ~~ XMLRepresentation {
                        @item-desc.push: LibXML::Class::ItemDescriptor.new: $_, :xml-name(.xml-class.^xml-name), |%std;
                    }
                    elsif $any === NOT-SET {
                        LibXML::Class::X::Sequence::NotAny.new(:type(typeobj),
                                                               :why("can't use a bare type '" ~ .^name ~ "' with it"))
                            .throw
                    }
                    else {
                        # A bare non-xml-element type would derive its namespace.
                        @item-desc.push:
                            LibXML::Class::ItemDescriptor.new: $_, :derive(xml-implicit-value(True)), |%std;
                    }
                }
                default {
                    my $is-composed = True;
                    try { $is-composed = .^is_composed; }
                    if $is-composed {
                        LibXML::Class::X::Sequence::ChildType.new(:type(typeobj), :child-decl(ctype)).throw
                    }
                    @item-desc.push: LibXML::Class::ItemDescriptor.new(:type($_<>), |%std);
                }
            }
        }

        typeobj.^xml-set-sequence-any($any !=== NOT-SET);
        typeobj.^xml-set-item-descriptors(@item-desc);
    }

    my subset TraitArg of Any where Bool:D | Str:D;

    my sub no-extra-nameds(%named) {
        if %named {
            my $singular = %named.keys == 1;
            LibXML::Class::X::Trait::Argument.new(
                :$singular,
                :why("named" ~ ($singular ?? "" !! "s")
                    ~ " '" ~ %named.keys.sort.join("', '") ~ "'") ).throw
        }
    }

    my proto sub typeobj-as-element(|) {*}

    multi sub typeobj-as-element(Mu:U \typeobj, *@pos, *%params) {
        my $pos;
        if @pos == 1 && ($pos = @pos.head) !~~ TraitArg {
            LibXML::Class::X::Trait::Argument.new(
                :why("$*LIBXML-CLASS-TRAIT name must be a string, not "
                    ~ ($pos andthen "an instance of " orelse "a type object ") ~ $pos.^name)).throw
        }
        elsif @pos > 1 {
            LibXML::Class::X::Trait::Argument.new(
                :why("too many positionals for trait $*LIBXML-CLASS-TRAIT")).throw
        }

        if $pos ~~ Str:D {
            %params<xml-name> = $pos;
        }

        given typeobj.HOW {
            when Metamodel::ClassHOW {
                samewith(|%params, :class(typeobj))
            }
            when Metamodel::ParametricRoleHOW {
                samewith(|%params, :role(typeobj))
            }
            default {
                LibXML::Class::X::UnsupportedType.new(:type(typeobj)).throw
            }
        }
    }

    multi sub typeobj-as-element( Mu :$class! is raw,
                                  Str :$xml-name,
                                  Bool :$implicit,
                                  SerializeSeverity :$severity,
                                  Mu :$sequence = NOT-SET,
                                  Mu :$any = NOT-SET,
                                  Bool :$lazy,
                                  :$derive,
                                  Bool :$impose-ns,
                                  :$ns is raw,
                                 *%named )
    {
        no-extra-nameds(%named);

        if $class.HOW ~~ LibXML::Class::HOW::Element {
            LibXML::Class::X::Redeclaration::Type.new(:type($class), :kind<class>, :what<xml-element>).throw;
        }

        # If a role is consumed where a parent is xml-element this may result in inability to build c3mro due to
        # an ambiguity about LibXML::Class::Object. The ambiguity is resolved the trait goes before that role.
        my sub is-Object(Mu $role is raw) is raw {
            my \rhow = $role.HOW;
            if rhow ~~ Metamodel::ParametricRoleHOW {
                return ($role.^parents(:local).any ~~ XMLObject) || $role.^roles(:transitive).map({ is-Object($_) })
                    .any;
            }
            elsif rhow ~~ Metamodel::ParametricRoleGroupHOW {
                return $role.^candidates.map({ is-Object($_) }).any
            }
            elsif rhow ~~ Metamodel::CurriedRoleHOW {
                return $role.^role_typecheck_list.map({ is-Object($_) }).any
            }
            die "Cannot check if object ", $role.^name, " of ", $role.HOW.^name, " is an xml-element";
        }
        for $class.^role_typecheck_list -> Mu $role is raw {
            LibXML::Class::X::TraitPosition.new(:trait<xml-element>, :$class, :$role).throw if is-Object($role);
        }

        if $sequence !=== NOT-SET {
            $class.HOW does LibXML::Class::HOW::ElementSeq[LibXML::Class::HOW::Element];
            $class.^add_role(XMLSequential);
        }
        else {
            $class.HOW does LibXML::Class::HOW::Element;
            $class.^add_role(XMLRepresentation);
        }

        my %config-defaults = |(:$severity with $severity), |(:$derive with $derive);
        $class.^xml-set-name($_) with $xml-name;
        $class.^xml-set-ns-defaults($_) with $ns;
        $class.^xml-set-impose-ns($_) with $impose-ns;
        $class.^xml-set-explicit(!$_) with $implicit;
        with $lazy {
            $class.^xml-set-lazy($lazy);
            %config-defaults<eager> = !$lazy;
        }
        else {
            # Default is lazy but without eager being explicitly specified...
            $class.^xml-set-lazy(True);
        }

        typeobj-as-sequence($class, $sequence, $any) unless $sequence === NOT-SET;

        $class.^xml-set-config-defaults: %config-defaults;
    }

    multi sub typeobj-as-element( Mu :$role! is raw,
                                  Str :$xml-name,
                                  Bool :$implicit,
                                  Bool :$impose-ns,
                                  Bool :$lazy,
                                  :$ns,
                                  :$sequence,
                                  Mu :$any = NOT-SET,
                                  *%named )
    {
        no-extra-nameds(%named);

        if $role.HOW ~~ LibXML::Class::HOW::ElementRole {
            LibXML::Class::X::Redeclaration::Type.new(:type($role), :kind<role>, :what<xml-element>).throw;
        }

        with $sequence {
            typeobj-as-sequence($role, LibXML::Class::HOW::ElementRole, $sequence, $any);
        }
        else {
            $role.HOW does LibXML::Class::HOW::ElementRole;
        }

        $role.^xml-set-lazy($lazy) with $lazy;
        $role.^xml-set-ns-defaults($_) with $ns;
        $role.^xml-set-explicit(!$_) with $implicit;
        $role.^xml-set-impose-ns($_) with $impose-ns;
        $role.^xml-set-name($_) with $xml-name;
    }

    multi sub trait_mod:<is>(Mu:U \typeobj, :$xml-element!) is export {
        my $*LIBXML-CLASS-TRAIT = "xml-element";
        typeobj-as-element(typeobj, |$xml-element.List.Capture)
    }

    multi sub trait_mod:<is>(Attribute:D $attr, :$xml-attribute!) is export {
        my $*LIBXML-CLASS-TRAIT = "xml-attribute";
        LibXML::Class::Attr::mark-attr-xml($attr, |$xml-attribute.List.Capture, :!as-xml-element);
        # Unless the owning package is manually marked as implicit any explicitly marked attribute turns it into an
        # explicit one.
        $*PACKAGE.^xml-set-explicit(True);
    }

    multi sub trait_mod:<is>(Attribute:D $attr, :$xml-element!) is export {
        my $*LIBXML-CLASS-TRAIT = "xml-element";
        LibXML::Class::Attr::mark-attr-xml($attr, |$xml-element.List.Capture, :as-xml-element);
        $*PACKAGE.^xml-set-explicit(True);
    }

    multi sub trait_mod:<is>(Attribute:D $attr, :$xml-text!) is export {
        my $*LIBXML-CLASS-TRAIT = "xml-text";
        LibXML::Class::Attr::mark-attr-xml($attr, |$xml-text.List.Capture, :as-xml-text);
        $*PACKAGE.^xml-set-explicit(True);
    }

    sub xml-I-cant(--> Nil) is export { LibXML::Class::CX::Cannot.new.throw }
}

our sub META6 {
    $?DISTRIBUTION.meta
}