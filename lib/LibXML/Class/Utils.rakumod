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

sub parse-ns-definitions(+@ns-defs) is raw is export {
    my $default-ns := Nil;
    my $default-ns-pfx := Nil;
    my @xml-ns;
    for @ns-defs -> $ns-def {
        given $ns-def {

            my sub bad-ns(Str:D $why) {
                LibXML::Class::X::Namespace::Definition.new(:$why, :what($_)).throw
            }

            when Str:D | Whatever {
                bad-ns("only one default URI can be set") with $default-ns;
                $default-ns := $_;
            }
            when Pair:D {
                bad-ns("prefix must be a string") unless .key ~~ Str:D;
                if $ns-def.value === True {
                    bad-ns("only one default prefix can be set") with $default-ns-pfx;
                    $default-ns-pfx := $ns-def.key;
                }
                else {
                    bad-ns("URI must be a string") unless .value ~~ Str:D;
                    @xml-ns.push: $_;
                }
            }
            default {
                bad-ns("must be a Pair object or a default URI value")
            }
        }
    }

    ($default-ns, $default-ns-pfx, @xml-ns.List)
}
