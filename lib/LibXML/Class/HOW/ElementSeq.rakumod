use v6.e.PREVIEW;
# WITH-HOW defined the base HOW role we must also apply.
unit role LibXML::Class::HOW::ElementSeq[::WITH-HOW];
use experimental :will-complain;

use LibXML::Element;

use LibXML::Class::ItemDescriptor;

also does WITH-HOW;

# Tags allowed for sequence
has List $!xml-item-descriptors;
# As collected from MRO
has List $!xml-all-item-descriptors;

# Whether this class was declared as xml-any
has Bool $!xml-any;

# !!! The following 3 attributes are set with !xml-build-from-mro method.
# Map item types into corresponding item descriptors.
has $!xml-type2desc;
# Either we or any parent class is marked xml-any
has $!xml-either-any;
# Parameterized array type for XMLSequence class @!xml-items
has Mu $!xml-array-type;

method xml-set-item-descriptors(Mu, @desc) {
    $!xml-item-descriptors := @desc.List
}

method xml-set-sequence-any(Mu, Bool:D $!xml-any) {}

method xml-item-descriptors(Mu) { $!xml-item-descriptors // ($!xml-item-descriptors := ()) }
method xml-any(Mu) { $!xml-any }

# Use a dedicated method to reduce closure size captured by the custom subset type XMLChildTypes created.
method xml-build-array-type(@child-types) {
    my @ctype-names = @child-types.map(*.^name);

    my $subset-name = "XMLSequenceOf(" ~ @ctype-names.join("|") ~ ")";
    # The subset will use this "pre-cached" junction from the closure instead of re-building it every time
    # at run-time.
    my $any-child-type = @child-types.any;

    # Create a subset to validate sequence element types
    my \XMLChildTypes =
        Metamodel::SubsetHOW.new_type:
            :name($subset-name),
            :refinee(Mu),
            :refinement({ $_ ~~ $any-child-type });

    # Make the subset produce meaningful error message on type check failure
    &trait_mod:<will>(:complain, XMLChildTypes,
                      { "expected any of " ~ @ctype-names.join(",") ~ " but got " ~ .^name ~ " ($_)" });

    $!xml-array-type := Array.^parameterize(XMLChildTypes);
}

method xml-build-from-mro(Mu \obj) {
    my Array[LibXML::Class::ItemDescriptor:D] %type2desc{Mu:U};
    my @child-types;
    my @all-desc;

    $!xml-either-any = False;

    for self.mro(obj, :roles).grep({ .HOW ~~ ::?ROLE }).reverse -> \typeobj {
            # note "? 0. ", %type2desc.raku;
        # With .reverse and the following notation subclasses can override child element declarations. Say, Seq1
        # defines a child :foo(Foo), but Seq2 is Seq1 and defines :foo(Bar). Then sequence tag <foo> would resolve
        # into Bar for Seq2 instances.
        for typeobj.^xml-item-descriptors -> LibXML::Class::ItemDescriptor:D $desc {
            # note "? 1a. ", %type2desc.raku;
            # %type2desc{$desc.type.WHAT} := my LibXML::Class::ItemDescriptor:D @;
            # # note "? 1b. ", %type2desc.raku;
            # # note "? ON ", obj.^name, " for ", $desc.type.^name, ": ", %type2desc{$desc.type}.WHICH;
            # %type2desc{$desc.type.WHAT}.push: $desc;
            %type2desc.append: ($desc.nominal-type.WHAT) => $desc;
            @all-desc.push: $desc;
            @child-types.push: $desc.nominal-type;
            # note "? 2. ", %type2desc.raku;
        }

        $!xml-either-any ||= typeobj.^xml-any;
    }

    $!xml-type2desc := %type2desc;
    $!xml-all-item-descriptors := @all-desc.List;
    self.xml-build-array-type(@child-types);
}

method xml-all-item-descriptors(Mu \obj) is raw {
    self.xml-build-from-mro(obj) without $!xml-all-item-descriptors;
    $!xml-all-item-descriptors
}

method xml-array-type(Mu \obj) is raw {
    self.xml-build-from-mro(obj) without $!xml-either-any;
    $!xml-array-type
}
method xml-either-any(Mu \obj) {
    self.xml-build-from-mro(obj) without $!xml-either-any;
    ? $!xml-either-any
}

# method xml-desc-for-elem(Mu \obj, LibXML::Element:D $elem) {
#     self.xml-build-from-mro(obj) without $!xml-either-any;

#     note "??? DESC FROM ELEM ", $elem.name, " from ", $elem.namespaceURI;

#     ($!xml-tag2desc{$elem.namespaceURI // ""} andthen .{$elem.localName}) // Nil
# }

method xml-desc-for-type(Mu \obj, Mu $item --> Positional) {
    self.xml-build-from-mro(obj) without $!xml-either-any;

    my \item-WHAT = $item.WHAT;
    return $_ with $!xml-type2desc{item-WHAT};

    # If there is no direct mapping for the type then try to find the descriptor by matching. This branch would fire up
    # for when we have roles or nominalizables registered.

    for $!xml-type2desc.keys -> \type-matcher {
        return $!xml-type2desc{type-matcher} if item-WHAT ~~ type-matcher;
    }

    # No candidate descriptor found.
    Empty
}

# Copyright (c) 2023, Vadim Belman <vrurg@cpan.org>
#
# See the LICENSE file for the license