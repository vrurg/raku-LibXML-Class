use v6.d;
unit role LibXML::Class::HOW::Explicit;

# Type object is explicit if explicitly marked attributes only are used for (de-)serialization
has Bool $!explicit;

method xml-set-explicit(Mu $, Bool:D $explicit) {
    # Write-once semantics. So, it set explicitly with xml-element trait then cannot be changed
    $!explicit //= $explicit;
}

method xml-is-explicit(Mu) {
    ?$!explicit
}
