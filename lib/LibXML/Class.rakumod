use v6.e.PREVIEW;
unit module LibXML::Class;
use nqp;
use experimental :will-complain;

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
use LibXML::Class::Document;
use LibXML::Class::HOW::Element;
use LibXML::Class::HOW::ElementRole;
use LibXML::Class::HOW::ElementSeq;
use LibXML::Class::ItemDescriptor;
use LibXML::Class::Node;
use LibXML::Class::NS;
use LibXML::Class::X;
use LibXML::Class::XML;
use LibXML::Class::Types;
use LibXML::Class::Utils;

role XMLRepresentation {...}
role XMLSequential {...}

my class DeserializingCtx {
    has XMLRepresentation:U $.into is required;
    has LibXML::Element:D $.elem is required;
    has LibXML::Class::Document:D $.xml-document is required;
    has LibXML::Document:D $.elem-document = $!elem.ownerDocument;
    has LibXML::Class::Config:D $.config = $!xml-document.config;
    has LibXML::Node @.child-elems = $!elem.elements;
    has Map $!child-idx = @!child-elems.map(*.unique-key).antipairs.Map;
    has LibXML::Node @.attributes = $!elem.properties;
    has Map $!attr-idx = @!attributes.map(*.unique-key).antipairs.Map;
    has %.user-profile;
    # User input to from-xml method
    has %.profile = :$!xml-document;
    # The resulting profile
    has %.ns-pfx;
    # All NS prefixes mapping into URIs from all parent classes

    # Map namespace/node name into Raku attributes
    has %!xml-props;
    has %!xml-tags;
    has $.xml-text;

    submethod TWEAK {
        without %!profile<xml-namespaces> {
            %!profile<xml-namespaces> = $!elem.namespaces.map({ .declaredPrefix => .declaredURI });
        }

        %!profile<xml-default-ns> //= $_ with $!elem.namespaceURI;
        %!profile<xml-default-ns-pfx> //= $_ with $!elem.prefix;

        # Build context-dependent mappings of namespace/XML node name into Raku class attribute objects
        for $!into.^mro.reverse.map(*.^attributes.grep(LibXML::Attr::XMLish)).flat {
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
    }

    # Finds the default NS URI for a LibXML::Class node based on the current context namespaces
    method !ns-default(LibXML::Class::NS:D $node, :$overrides = True) {
        return $_ with $node.xml-default-ns;
        return "" unless $node.xml-default-ns || $node.xml-default-ns-pfx;

        my %nsp := $overrides
            ?? %(|%!ns-pfx, |$node.xml-namespaces)
            !! %!ns-pfx;

        %nsp{$node.xml-default-ns-pfx}
            // LibXML::Class::X::Namespace::Prefix.new(:type($!into), :prefix($node.xml-default-ns-pfx)).throw
    }

    method !add-attribute($attr, $name, %into is raw) {
        my $nsURI = self!ns-default($attr);
        with %into{$nsURI}{$name} {
            # Some other attribute has already claimed this node under the same namespace
            LibXML::Class::X::AttrDuplication::Attr.new(:type($!into), :$nsURI, :$name, :attrs($_, $attr)).throw
        }
        %into{$nsURI}{$name} = $attr;
    }

    # attr-for- methods map a LibXML::Node into a LibXML::Class attribute based on the node namespace.
    # The matching NS is passed into &with callback for later use.
    method attr-for-prop(LibXML::Attr:D $xml-attr, &with --> LibXML::Class::Attr::XMLish) {
        my $nsURI = $xml-attr.namespaceURI // "";
        my $xml-name = $xml-attr.name;
        ((%!xml-props{$nsURI} andthen .{$xml-name}) orelse (%!xml-props{*} andthen .{$xml-name}))
            andthen &with($_, $nsURI)
            orelse Nil
    }

    method attr-for-elem(LibXML::Element:D $elem, &with --> LibXML::Class::Attr::XMLish) {
        my $nsURI = $elem.namespaceURI // "";
        my $elem-name = $elem.localname;
        ((%!xml-tags{$nsURI} andthen .{$elem-name}) orelse (%!xml-tags{*} andthen .{$elem-name}))
            andthen &with($_, $nsURI)
            orelse Nil
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
        @!attributes[$!attr-idx{$attr.unique-key}]
    }

    proto method to-profile(|) {*}

    multi method to-profile(LibXML::Class::Attr::XMLish:D $attr, Mu \value, *%c --> Nil) {
        samewith $attr.name.substr(2), value, :positional($attr ~~ LibXML::Class::Attr::XMLPositional), |%c, :$attr;
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

        # Could as well remain a Hash but immutability is desired.
        with %!profile<xml-lazies> {
            $_ = .Map;
            %!profile<xml-backing> = $!elem;
        }

        %( |%!profile, |%!user-profile)
    }
}

class XMLObject does LibXML::Class::Node {
    # Collection of AST nodes representing XML entities which do not have mapping into our class
    has $.xml-unused is mooish(:lazy(-> $, *% { [] }));

    # The XML elemnt this object has been initialized from. Only makes sense for lazies.
    has LibXML::Element $.xml-backing;

    # Attribute name -> child node index on this class' element
    has Map $.xml-lazies;

    has LibXML::Class::Document $.xml-document;

    has LibXML::Class::Config $.xml-config is mooish(:lazy<xml-build-config>);

    # What we've got as from-xml %profile argument
    has %.xml-user-profile;

    submethod TWEAK {
        self.xml-init-ns-from-hows;
    }

    method xml-build-config {
        $!xml-document andthen .config orelse LibXML::Class::Config.global
    }

    method xml-serialize-stages is raw {
        ('xml-to-element-repr',)
    }
    method xml-profile-stages is raw {
        ('xml-from-element-repr',)
    }

    proto method xml-type-from-str(Mu:U, Str:D) {*}
    multi method xml-type-from-str(Bool, Str:D $xml-value) {
        ($xml-value eq "1" | "true")
            or ($xml-value eq "0" | "false"
            ?? False
            !! LibXML::Class::X::Deserialize::BadValue.new(:type(Bool), :value($xml-value)).throw)
    }
    multi method xml-type-from-str(::T Any:U, T(Str:D) \coerced) {
        coerced
    }

    proto method xml-type-to-str(|) {*}
    multi method xml-type-to-str(Bool:D \val) {
        val.Str.lc
    }
    multi method xml-type-to-str(Mu:D \val where *.HOW ~~ Metamodel::EnumHOW) {
        ~val.value
    }
    multi method xml-type-to-str(Mu \val) {
        ~val
    }

    # xml-coerce-into-attr always works on a single string or element. Any containerization, positionals are to be unwrapped
    # by the upstream. Since associatives are always single-elemented we do handle them in here.
    proto method xml-coerce-into-attr(Attribute:D, $) {*}

    multi method xml-coerce-into-attr(::?CLASS:D:
                                      LibXML::Class::Attr::XMLAssociative:D $attr,
                                      LibXML::Element:D $elem)
    {
        my \attr-type = $attr.type<>;
        my Mu \value-type = attr-type.of;
        my Mu \key-type = attr-type.keyof;

        my $deserializer := $attr.deserializer;
        my $value-attr = $attr.value-attr;
        my &mapper =
            $attr.has-deserializer
            ?? $value-attr
                ?? { self.xml-type-from-str(key-type, .localname) => $deserializer.(.getAttribute($value-attr)) }
                !! { self.xml-type-from-str(key-type, .localname) => $deserializer.(.textContent) }
            !! $value-attr
                ?? { self.xml-type-from-str(key-type, .localname) => self.xml-type-from-str(value-type,
                    .getAttribute($value-attr)) }
                !! { self.xml-type-from-str(key-type, .localname) => self.xml-type-from-str(value-type, .textContent) };

        attr-type.new: $elem.childNodes.map(&mapper)
    }

    multi method xml-coerce-into-attr(::?CLASS:D:
                                      LibXML::Class::Attr::XMLValueElement:D $attr,
                                      LibXML::Element:D $elem)
    {
        # Deserializer of an element attribute takes the element. We wash our hands here.
        return $attr.deserializer.($elem) if $attr.has-deserializer;

        if $attr.xml-any {
            my LibXML::Element:D $any-elem = $elem.elements.head;
            my \any-type = $!xml-config.ns-map($any-elem);
            if any-type === Nil {
                my $ex = LibXML::Class::X::Deserialize::NoNSMap.new(:elem($any-elem));
                $!xml-config.alert: $ex;
                # Unless severity level is  STRICT then return a Failure. If that's ok with the user and their
                # destination container allows for it then that failure can be used by serialization to reproduce the
                # original element. Otherwise throwing due to failed typecheck would be a totally reasonable outcome.
                fail $ex
            }
            return any-type.from-xml($any-elem, $!xml-document, |%!xml-user-profile)
        }

        my Mu \attr-type = ($attr.sigil eq '@' ?? .of !! .type)<> given $attr.type;

        # If destination type is an XMLRepresentation then let it deserialize itself
        return attr-type.from-xml($elem, $!xml-document, |%!xml-user-profile) if attr-type ~~ XMLRepresentation;

        # Otherwise this is a case of a simple element where we need either its text content or value attribute.
        self.xml-type-from-str($attr.type, ($_ ?? $elem.getAttribute($_) !! $elem.textContent)) given $attr.value-attr;
    }

    multi method xml-coerce-into-attr(::?CLASS:D:
                                      LibXML::Class::Attr::XMLAttribute:D $attr,
                                      LibXML::Attr:D $xml-attr)
    {
        my \attr-type = $attr.type<>;
        $attr.has-deserializer
            ?? $attr.deserializer.($xml-attr.value)
            !! self.xml-type-from-str(attr-type, $xml-attr.value)
    }

    multi method xml-coerce-into-attr(::?CLASS:D: LibXML::Class::Attr::XMLTextNode:D $attr, Str:D $xml-value) {
        my \attr-type = $attr.type<>;
        $attr.has-deserializer
            ?? $attr.deserializer.($xml-value)
            !! self.xml-type-from-str(attr-type, $xml-value)
    }

    # This method is to be used as the builder for lazy attributes.
    proto method xml-deserialize-attr(::?CLASS:D: |) {*}

    # This candidate would basically serve as the entry point because $attribute is always passed in by AttrX::Mooish
    multi method xml-deserialize-attr(::?CLASS:D: Str:D :$attribute!) {
        nextwith $attribute, self.^get_attribute_for_usage($attribute)
    }

    multi method xml-deserialize-attr(::?CLASS:D: Str:D $attr-name, LibXML::Class::Attr::XMLPositional:D $attr) {
        $!xml-lazies{$attr-name} andthen .map(self.xml-coerce-into-attr($attr, *))
    }

    multi method xml-deserialize-attr(::?CLASS:D: Str:D $attr-name, LibXML::Class::Attr::XMLish:D $attr) {
        $!xml-lazies{$attr-name} andthen self.xml-coerce-into-attr($attr, $_) orelse Nil
    }

    method xml-decontainerize(LibXML::Element:D $elem,
                              LibXML::Class::Attr::XMLContainer:D $attr,
                              Str:D $expected-ns-URI = "",
        # Should we throw away empty #text?
                              Bool :$trim
        --> Seq:D)
    {
        return $elem.Seq unless $attr.container;

        # If we got here it means the container element has been validated already and matches NS and container name
        # of the attribute $attr
        gather {
            for $elem.children -> LibXML::Node:D $child {
                if $child ~~ LibXML::Text {
                    next if $trim && !$child.data.trim;
                    take $child;
                }
                else {
                    if (my $childNS = $child.namespaceURI // "") ne $expected-ns-URI {
                        # Mismatch of container's child element to the expected namespace is not ignorable.
                        LibXML::Class::X::Namespace::Mismatch.new(
                            :expected($expected-ns-URI),
                            :got($childNS),
                            :what("child element '" ~ $child.name ~ "' of container '" ~ $elem.name ~ "'")).throw
                    }
                    take $child
                }
            }
        }
    }

    # Serialize a value based on attribute meta data.
    method xml-ser-maybe-container(LibXML::Element:D $elem,
                                   LibXML::Class::Attr::XMLContainer:D $xml-attr,
                                   Str:D $elem-name) {
        my $document = $elem.ownerDocument;
        my LibXML::Element:D $aelem = $document.createElement($elem-name);
        my LibXML::Element:D $celem = $aelem;
        if $xml-attr.container -> $cname {
            $celem = $document.createElement($cname);
            $celem.add: $aelem;
        }

        $elem.add: $celem;
        $xml-attr.xml-apply-ns($celem);

        # Return the actual value element because this is where the actual data would be stored
        $aelem
    }

    method xml-ser-attr-value(LibXML::Class::Attr::XMLish:D $xml-attr, Mu $attr-value is raw --> Str:D) {
        $xml-attr.has-serializer
            ?? $xml-attr.serializer.($attr-value)
            !! self.xml-type-to-str($attr-value)
    }

    method xml-ser-attr-val2elem(LibXML::Element:D $elem, LibXML::Class::Attr::XMLish:D $xml-attr, Mu $attr-value) {
        if $xml-attr.value-attr -> $xml-aname {
            # Attribute value is to be kept in XML element attribute
            $elem.setAttribute($xml-aname, self.xml-ser-attr-value($xml-attr, $attr-value))
        }
        elsif !$xml-attr.has-serializer and ($attr-value ~~ XMLRepresentation || $attr-value !~~ BasicType) {
            my $cvalue = $attr-value;
            unless $cvalue ~~ XMLRepresentation {
                # Turn a basic class into an XMLRepresentation with implicit flag raised
                $cvalue = $*LIBXML-CLASS-CONFIG.xmlize($attr-value, XMLRepresentation);
            }
            my $celem = $elem.ownerDocument.createElement($attr-value.^shortname);
            $elem.add: $celem;
            $cvalue.to-xml($celem);
        }
        else {
            $elem.appendText(self.xml-ser-attr-value($xml-attr, $attr-value));
        }
        $elem
    }

    proto method xml-serialize-attr(LibXML::Element:D, LibXML::Class::Attr::XMLish:D) {*}

    multi method xml-serialize-attr(LibXML::Element:D $elem, LibXML::Class::Attr::XMLAttribute:D $xml-attr) {
        my $attr-value := $xml-attr.attr.get_value(self);

        return without $attr-value;

        my $xml-attr-name = $xml-attr.xml-name;
        my $xml-attr-value = self.xml-ser-attr-value($xml-attr, $attr-value);

        with $xml-attr.xml-get-ns-default($elem) {
            $elem.setAttributeNS: .declaredURI, $xml-attr-name, $xml-attr-value;
        }
        else {
            $elem.setAttribute: $xml-attr-name, $xml-attr-value;
        }
    }

    multi method xml-serialize-attr(LibXML::Element:D $elem, LibXML::Class::Attr::XMLTextNode:D $xml-attr) {
        with $xml-attr.get_value(self) {
            $elem.appendText: self.xml-ser-attr-value($xml-attr, $_);
        }
    }

    multi method xml-serialize-attr(LibXML::Element:D $elem, LibXML::Class::Attr::XMLPositional:D $xml-attr) {
        my @attr-values = $xml-attr.get_value(self);

        return unless @attr-values;

        my $document = $elem.ownerDocument;

        # Positional containerization differs from other elements since by default their elements are direct
        # children of the parent.
        my LibXML::Element:D $celem = $elem;
        if $xml-attr.container -> $cname {
            $celem = $document.createElement($cname);
            $elem.add: $celem;
            $xml-attr.xml-apply-ns($celem);
        }

        my ($nsURI, $nsPrefix) = ($xml-attr.xml-get-ns-default($celem) andthen (.declaredURI, .declaredPrefix));
        my $velem-name = $xml-attr.xml-name;
        for @attr-values -> $avalue {
            my $velem = self.xml-ser-attr-val2elem: $document.createElement($velem-name), $xml-attr, $avalue;
            $celem.add: $velem;
            $velem.setNamespace($nsURI, $nsPrefix) if $nsURI;
        }
    }

    multi method xml-serialize-attr(LibXML::Element:D $elem, LibXML::Class::Attr::XMLAssociative:D $xml-attr) {
        my %attr-values = $xml-attr.get_value(self);

        return unless %attr-values;

        my $document = $elem.ownerDocument;

        $elem.add:
            my LibXML::Element:D $celem = $document.createElement($xml-attr.xml-name);
        $xml-attr.xml-apply-ns($celem);

        my ($nsURI, $nsPrefix) = ($xml-attr.xml-get-ns-default($celem) andthen (.declaredURI, .declaredPrefix));

        for %attr-values.sort -> (:key($vname), :$value) {
            my LibXML::Element:D $velem =
                self.xml-ser-attr-val2elem: $celem.add($document.createElement($vname)), $xml-attr, $value;
            $velem.setNamespace($nsURI, $nsPrefix) if $nsURI;
        }
    }

    multi method xml-serialize-attr(LibXML::Element:D $elem, LibXML::Class::Attr::XMLValueElement:D $xml-attr) {
        my $attr-value := $xml-attr.get_value(self);

        return without $attr-value;

        my $attr-type := $xml-attr.type;

        # Element name rules:
        # 1. explicitly defined with xml-elem
        # 2. attribute name for basic type values
        # 3. explicitly defined for value type if it is an xml-element
        # 4. type name for a non-basic type
        my $elem-name = $xml-attr.has-xml-name || ($attr-type =:= Any | Mu) || ($attr-type !~~ XMLRepresentation) ||
            $attr-value ~~ BasicType
            ?? $xml-attr.xml-name
            !! $attr-value ~~ LibXML::Class::Node
            ?? $attr-value.xml-name
            !! $attr-value.^shortname;

        self.xml-ser-attr-val2elem: self.xml-ser-maybe-container($elem, $xml-attr, $elem-name), $xml-attr, $attr-value;
    }

    method xml-to-element-repr(LibXML::Element:D $elem) {
        for self.^xml-attrs(:!local).values -> LibXML::Class::Attr::XMLish:D $xml-attr {
            self.xml-serialize-attr($elem, $xml-attr)
        }
    }

    method xml-to-element(::?CLASS:D:
                          LibXML::Element:D $elem,
                          LibXML::Class::Config:D :$config
                          ) is implementation-detail
    {
        self.xml-apply-ns($elem);

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
    }

    method xml-new-dctx(*%profile) {
        DeserializingCtx.new: |%profile
    }

    method xml-from-element(LibXML::Element:D $elem, LibXML::Class::Document:D $doc, %user-profile) {
        my %ns-pfx = |(%*LIBXML-CLASS-NS-PFX || ()), |self.xml-collect-from-hows;
        my $dctx = self.xml-new-dctx: :into(::?CLASS), :$elem, :xml-document($doc), :%user-profile, :%ns-pfx;

        {
            my %*LIBXML-CLASS-NS-PFX = %ns-pfx;
            my $*LIBXML-CLASS-CTX = $dctx;

            for self.xml-profile-stages -> $stage {
                self."$stage"($dctx);
            }
        }

        my %profile = $dctx.final-profile;
        if $dctx.config.severity !== EASY && %profile<xml-unused> {
            $dctx.config.alert: LibXML::Class::X::UnclaimedNodes.new(:$elem, :unclaimed(%profile<xml-unused><>));
        }

        self.new: |%profile
    }

    method clone-from(Mu:D $obj) {
        my %profile;
        for $obj.^attributes(:!local).grep({ .has_accessor || .is_built }) -> Attribute:D $attr {
            %profile{$attr.name.substr(2)} := $attr.get_value($obj);
        }
        self.new: |%profile
    }

    proto method xml-config-context(|) {*}
    multi method xml-config-context(&code, LibXML::Class::Config:D :$config) is raw {
        my $*LIBXML-CLASS-CONFIG = $config;
        &code($config)
    }
    multi method xml-config-context(&code, LibXML::Class::Document :$document, LibXML::Config :$libxml-config,
                                    :%config) {
        %config<libxml-config> = $_ with $libxml-config;

        my $config = ((CALLERS::<$*LIBXML-CLASS-CONFIG>:exists
            ?? CALLERS::<$*LIBXML-CLASS-CONFIG>
            !! ($document && $document.config))
            andthen (%config ?? .clone(|%config) !! $_)
            orelse LibXML::Class::Config.new(|self.xml-config-defaults, |%config));

        my $*LIBXML-CLASS-CONFIG = $config;

        &code($config)
    }

    proto method from-xml(|) {*}
    multi method from-xml(Str:D $source-xml,
                          LibXML::Class::Document :$document is copy,
                          :$config,
                          *%profile)
    {
        my LibXML::Class::Document:D $new-doc = self.xml-config-context: :$document, :$config, {
            .document-class.parse(string => $source-xml, :config($_));
        }
        nextwith($new-doc.document.documentElement, :document($new-doc), |%profile)
    }
    multi method from-xml(LibXML::Document:D $xml-doc,
                          LibXML::Class::Document :$document,
                          :$config,
                          *%profile)
    {
        my LibXML::Class::Document:D $new-doc =
            self.xml-config-context: :$document, :libxml-config($xml-doc.config), :$config, {
                .document-class.new(:document($xml-doc), :config($_));
            };
        nextwith($new-doc.document.documentElement, $new-doc, |%profile)
    }
    multi method from-xml(LibXML::Element:D $elem,
                          LibXML::Class::Document $document? is copy,
                          :$config,
                          *%profile)
    {
        without $document {
            my LibXML::Document:D $xml-doc = $elem.ownerDocument;
            $document = self.xml-config-context: :libxml-config($xml-doc.config), :$config, {
                .document-class.new(:document($xml-doc), :config($_))
            }
        }
        my $*LIBXML-CLASS-DOCUMENT = $document;
        my $*LIBXML-CLASS-CONFIG = $document.config;
        self.xml-from-element($elem, $document, %profile);
    }

    proto method to-xml(::?CLASS:D: |) {*}
    multi method to-xml(::?CLASS:D: LibXML::Document $doc? is copy, Str :$name, *%profile) {
        self.xml-config-context: |%profile, {
            $doc //= LibXML::Document.new(:config(.libxml-config));
            $doc.documentElement = self.to-xml($doc.createElement($name // $.xml-name));
            $doc
        }
    }
    multi method to-xml(::?CLASS:D: LibXML::Element:D $elem, *%profile) {
        self.xml-config-context: |%profile, {
            self.xml-to-element($elem, :config($_))
        }
        $elem
    }
}

our role XMLRepresentation does LibXML::Class::XML is XMLObject {
    method xml-build-name {
        (::?CLASS.^xml-name if ::?CLASS.HOW ~~ LibXML::Class::HOW::Element) // ::?CLASS.^shortname
    }

    method xml-config-defaults {
        ::?CLASS.^xml-config-defaults
    }

    method xml-from-element-repr(DeserializingCtx:D $dctx) {
        callsame();

        my $config = $dctx.config;
        my $lazy-class = ::?CLASS.^xml-is-lazy;
        my $force-eager = $config.eager;

        for $dctx.unclaimed-attrs -> LibXML::Attr:D $xml-attr {
            $dctx.attr-for-prop: $xml-attr, -> LibXML::Class::Attr::XMLAttribute:D $attr, $ {
                if !$force-eager && ($attr.xml-lazy // $lazy-class) {
                    $dctx.add-lazy($attr, $xml-attr);
                }
                else {
                    $dctx.to-profile:
                        $attr,
                        self.xml-coerce-into-attr($attr, $xml-attr.value),
                        :node($xml-attr);
                }

                $dctx.claim-attr($xml-attr);
            }
        }

        for $dctx.unclaimed-children -> LibXML::Element:D $elem {
            $dctx.attr-for-elem: $elem, -> LibXML::Class::Attr::XMLish:D $attr, Str:D $nsURI {
                my $value-elems := self.xml-decontainerize($elem, $attr, $nsURI, :trim);

                # Validate xml:any by making sure number of XML elements matches attribute declaration.
                if $attr.xml-any {
                    if $attr.sigil ne '@' && $value-elems.elems > 1 {
                        $dctx.config.alarm:
                            LibXML::Class::X::Deserialize::BadNode.new(
                                :expected("single element for xml:any attribute " ~ $attr.name),
                                :got($value-elems.elems))
                    }
                    else {
                        for $value-elems.List -> $velem {
                            if $velem.elements > 1 {
                                $dctx.config.alarm:
                                    LibXML::Class::X::Deserialize::BadNode.new(
                                        :expected("single child under xml:any element '" ~ $velem.name ~ "'"),
                                        :got($velem.elements.elems))
                            }
                        }
                    }
                }

                if !$force-eager && ($attr.xml-lazy // $lazy-class) {
                    # Lazy xml-element attribute
                    for $value-elems {
                        $dctx.add-lazy($attr, $_);
                    }
                }
                else {
                    for $value-elems {
                        if $_ ~~ LibXML::Element {
                            # TODO We must ensure that a containerized item-element can be coerced into the attribute.
                            #      Or otherwise, say, we may attempt deserialize inappropariate one into a positional.
                            $dctx.to-profile: $attr, self.xml-coerce-into-attr($attr, $_), :node($elem);
                        }
                        else {
                            $dctx.config.alarm:
                                LibXML::Class::X::Deserialize::BadNode.new(
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

            if !$force-eager && (.xml-lazy // $lazy-class) {
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

    method xml-serialize-stages is raw {
        <xml-to-element-repr xml-to-element-seq>
    }
    method xml-profile-stages is raw {
        <xml-from-element-seq xml-from-element-repr>
    }

    method xml-from-element-seq(DeserializingCtx:D $dctx) {
        my $config = $dctx.config;
        #        my $force-eager = $config.eager;
        my $of-type := self.of;

        for $dctx.unclaimed-children -> LibXML::Element:D $elem {
            if self.xml-seq-desc-for-elem($elem)
                or ($!xml-is-any
                    # If xml:any then tag must be in the namespace map and match an allowed item type
                    && (my \any-type = $config.ns-map($elem)) !=== Nil
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

        if !@desc {
            $.xml-config.alert:
                LibXML::Class::X::Serialize::Impossible.new(
                    :what($item),
                    :why('the type is not registered with <' ~ $elem.localName ~ '>'));
            return Nil;
        }
        elsif @desc > 1 {
            $.xml-config.alert:
                LibXML::Class::X::Serialize::Impossible.new(
                    :what($item),
                    :why('too many declarations found for the type registered with <' ~ $elem.localName ~ '>'));
            return Nil
        }

        my LibXML::Class::ItemDescriptor:D $desc = @desc.head;

        return $desc if $desc.xml-name;

        # This object cannot carry objects of types not registered with specific XML names.
        unless self.xml-seq-either-any {
            $.xml-config.alert:
                LibXML::Class::X::Serialize::Impossible.new(
                    :what($item),
                    :why('<' ~ $elem.localName ~ '> is not xml-any, but the type has no associated name'));
            return Nil
        }

        # If the descriptor found doesn't have xml-name then it was a bare type registered with an xml-any type. We'd
        # need to pull the name with config's ns-map.

        my $ns = $desc.ns // $elem.namespaceURI;
        without my $ns-map = $.xml-config.ns-map-type($item.WHAT, :$ns) {
            $.xml-config.alert:
                LibXML::Class::X::Serialize::Impossible.new(
                    :what($item),
                    :why('cannot find a name for the type in config for sequential <' ~ $elem.localName ~ '>'));
            return Nil
        }

        $desc.clone: :$ns, :xml-name($ns-map.xml-name)
    }

    proto method xml-serialize-item(LibXML::Element:D, |) {*}

    multi method xml-serialize-item(LibXML::Element:D $elem, ::?CLASS:D $item) {
        my $name = self.xml-seq-desc-for-type($item) andthen .xml-name orelse Nil;
        $item.to-xml: $elem.ownerDocument, :$name
    }

    multi method xml-serialize-item(LibXML::Element:D $elem, BasicType $item) {
        without my LibXML::Class::ItemDescriptor $desc = self!xml-ser-guess-descriptor($elem, $item) {
            return Nil;
        }

        # We know the xml name for this item
        my LibXML::Element:D $item-elem =
            $elem.ownerDocument.createElement($desc.xml-name, |(:href($_) with $desc.ns));
        my $str = self.xml-type-to-str($item);
        with $desc.value-attr -> $attr-name {
            $item-elem.setAttribute($attr-name, $str);
        }
        else {
            $item-elem.appendText: $str
        }
        $item-elem
    }

    multi method xml-serialize-item(LibXML::Element:D $elem, Mu $item) {
        my $desc = self!xml-ser-guess-descriptor($elem, $item);
        # Don't XMLize with a custom name if there is one. Stick to defaults to avoid side effects.
        $.xml-config.xmlize($item).to-xml($elem.ownerDocument, :name($desc.xml-name // Nil))
    }

    method xml-to-element-seq(LibXML::Element:D $elem) {
        my Iterator:D $iter = self.iterator;
        loop {
            last if (my Mu $item := $iter.pull-one) =:= IterationEnd;
            with self.xml-serialize-item($elem, $item) -> LibXML::Element:D $child {
                $elem.appendChild: $child;
            }
            else {
                $.xml-config.alert:
                    LibXML::Class::X::Serialize::Impossible.new(:what($item), :why("no known serialization method"));
            }
        }
    }

    method xml-deserialize-item(LibXML::Class::ItemDescriptor:D $desc, LibXML::Element:D $elem, UInt:D :$index)
        is raw {
        my Mu $item-type := $desc.type;

        $item-type.^can('from-xml')
            ?? $item-type.from-xml($elem, $.xml-document, |%.xml-user-profile)
            !! $desc.value-attr
        ?? self.xml-type-from-str($item-type, $elem.getAttribute($desc.value-attr))
        !! self.xml-type-from-str($item-type, $elem.textContent)
    }

    method AT-POS(::?CLASS:D: $idx) {
        return @!xml-items[$idx] if @!xml-items[$idx]:exists;
        fail X::OutOfRange(:what<Index>, :got($idx), :range(0 .. self.end)) if $idx > self.end;

        # Item is not ready, deserialize corresponding element
        my LibXML::Element:D $elem = @!xml-seq-elems[$idx];
        my LibXML::Class::ItemDescriptor $desc = self.xml-seq-desc-for-elem($elem);

        if !$desc && $!xml-is-any {
            unless (my \item-type = $.xml-config.ns-map($elem)) =:= Nil {
                # When succeed in mapping an element into a type for xml-any try to go back to the registry and locate
                # a descriptor for the type.
                $desc = self.xml-seq-desc-for-type(item-type);
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
    method xml-seq-array-type { ::?CLASS.^xml-array-type }
    method xml-seq-either-any { ::?CLASS.^xml-either-any }
    method xml-seq-desc-for-elem(LibXML::Element:D $elem) { ::?CLASS.^xml-desc-for-elem($elem) }
    method xml-seq-desc-for-type(Mu $item) { ::?CLASS.^xml-desc-for-type($item) }
}

BEGIN {
    my class NOT-ANY is Nil {}

    my sub typeobj-as-sequence(Mu:U \typeobj, Mu:U \how-role, $sequence, Mu $any is raw) {
        my \child-types = $sequence.List;
        LibXML::Class::X::Sequence::NoChildTypes.new(:type(typeobj)).throw unless child-types.elems;

        my proto sub validate-args(Capture:D) {*}
        multi sub validate-args($ (Mu:U $type, Str :$attr, Str :namespace(:$ns), *%c)) {
            if %c {
                my $sfx = %c > 1 ?? "s" !! "";
                warn "Unexpected named argument$sfx passed to :sequence of 'xml-element' trait: "
                    ~ %c.keys.join(", ");
            }
            \(:$type, :value-attr($attr), :$ns)
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

        typeobj.HOW does LibXML::Class::HOW::ElementSeq[how-role];
        my Mu $seq-how := typeobj.HOW;
        my Str $ns = $seq-how.xml-guess-default-ns;
        my @item-desc;

        for child-types -> \ctype {
            my LibXML::Class::ItemDescriptor $child-desc;
            given ctype {
                when Pair:D {
                    # The order of constructor arguments is important here as client must be able to override the
                    # default naemspace, for example. And, yet, must not be able to use xml-name, not even by accident.
                    @item-desc.push:
                        LibXML::Class::ItemDescriptor.new(
                            :$ns,
                            |validate-args(.value.List.Capture),
                            :xml-name(.key),
                            :$seq-how);
                }
                when Mu:U {
                    if .HOW ~~ LibXML::Class::HOW::Element {
                        @item-desc.push: LibXML::Class::ItemDescriptor.new: $_, :xml-name(.^xml-name), :$seq-how, :$ns;
                    }
                    elsif $any === NOT-ANY {
                        LibXML::Class::X::Sequence::NotAny.new(:type(typeobj),
                                                               :why("can't use a bare type '" ~ .^name ~ "' with it"))
                            .throw
                    }
                    else {
                        @item-desc.push:
                            LibXML::Class::ItemDescriptor.new: $_, :$seq-how, :$ns;
                    }
                }
                default {
                    LibXML::Class::X::Sequence::ChildType.new(:type(typeobj), :child-decl(ctype)).throw
                }
            }
        }

        typeobj.^add_role(XMLSequential);
        typeobj.^xml-set-sequence-any($any !=== NOT-ANY);
        typeobj.^xml-set-item-descriptors(@item-desc);
    }

    my proto sub typeobj-as-element(|) {*}

    multi sub typeobj-as-element(Mu:U \typeobj,
                                 $pos?,
                                 *%params,
                                 Bool :$implicit,
                                 SerializeSeverity :$severity,
                                 Bool :$eager,
                                 :$ns)
    {
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

    multi sub typeobj-as-element(Mu :$class! is raw,
                                 Str :$xml-name,
                                 Bool :$implicit,
                                 SerializeSeverity :$severity,
                                 :$sequence,
                                 Mu :$any = NOT-ANY,
                                 Bool :$lazy,
                                 :$ns is raw)
    {
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

        with $sequence {
            typeobj-as-sequence($class, LibXML::Class::HOW::Element, $sequence, $any);
        }
        else {
            $class.HOW does LibXML::Class::HOW::Element;
            $class.^add_role(XMLRepresentation);
        }

        my %config-defaults = |(:$severity with $severity);
        $class.^xml-set-name($_) with $xml-name;
        $class.^xml-set-ns-defaults($_) with $ns;
        $class.^xml-set-explicit(!$_) with $implicit;
        with $lazy {
            $class.^xml-set-lazy($lazy);
            %config-defaults<eager> = !$lazy;
        }
        else {
            # Default is lazy but without eager being explicitly specified...
            $class.^xml-set-lazy(True);
        }
        $class.^xml-set-config-defaults: %config-defaults;
    }

    multi sub typeobj-as-element(Mu :$role! is raw, Bool :$implicit, :$ns, :$sequence, Mu :$any = NOT-ANY) {
        if $role.HOW ~~ LibXML::Class::HOW::ElementRole {
            LibXML::Class::X::Redeclaration::Type.new(:type($role), :kind<role>, :what<xml-element>).throw;
        }

        with $sequence {
            typeobj-as-sequence($role, LibXML::Class::HOW::ElementRole, $sequence, $any);
        }
        else {
            $role.HOW does LibXML::Class::HOW::ElementRole;
        }

        $role.^xml-set-ns-defaults($_) with $ns;
        $role.^xml-set-explicit(!$_) with $implicit;
    }

    multi sub trait_mod:<is>(Mu:U \typeobj, :$xml-element!) is export {
        my $*LIBXML-CLASS-TRAIT = "xml-element";
        typeobj-as-element(typeobj, |$xml-element.List.Capture)
    }

    multi sub trait_mod:<is>(Attribute:D $attr, :$xml-attribute!) is export {
        my $*LIBXML-CLASS-TRAIT = "xml-attribute";
        LibXML::Class::Attr::mark-attr-xml($attr, |$xml-attribute.List.Capture, :!as-xml-element)
    }

    multi sub trait_mod:<is>(Attribute:D $attr, :$xml-element!) is export {
        my $*LIBXML-CLASS-TRAIT = "xml-element";
        LibXML::Class::Attr::mark-attr-xml($attr, |$xml-element.List.Capture, :as-xml-element)
    }

    multi sub trait_mod:<is>(Attribute:D $attr, :$xml-text!) is export {
        my $*LIBXML-CLASS-TRAIT = "xml-text";
        LibXML::Class::Attr::mark-attr-xml($attr, |$xml-text.List.Capture, :as-xml-text)
    }
}

our sub META6 {
    $?DISTRIBUTION.meta
}