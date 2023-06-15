use v6.e.PREVIEW;
unit role LibXML::Class::HOW::Explicit;

# Type object is explicit if explicitly marked attributes only are used for (de-)serialization
has Bool $!explicit;

method xml-set-explicit(Mu \obj, Bool:D $explicit) {
    # Write-once semantics. So, it set explicitly with xml-element trait then cannot be changed
    $!explicit //= $explicit;
}

method xml-is-explicit(Mu) {
    ?$!explicit
}


# Copyright (c) 2023, Vadim Belman <vrurg@cpan.org>
#
# See the LICENSE file for the license