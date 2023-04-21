use v6.e.PREVIEW;
unit module LibXML::Class::Utils;

use LibXML::Namespace;

use LibXML::Class::Types;
use LibXML::Class::X;

sub nominalize-type(Mu \type) is raw is pure is export {
    type.^archetypes.nominalizable ?? type.^nominalize !! type
}

sub is-basic-type(Mu \type) is raw is pure is export {
    (type.^archetypes.nominalizable ?? type.^nominalize !! type) ~~ BasicType
}

# Standard merging of namespaces where later prefix definition doesn't override earlier one.
sub merge-in-namespaces(Associative:D \into, Associative \from) is export {
    for from.kv -> $pfx, $ns {
        into.{$pfx} = $ns unless into.EXISTS-KEY($pfx);
    }
}
