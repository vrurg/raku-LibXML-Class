use v6.e.PREVIEW;
unit module LibXML::Class::Types;

role IsImplicitValue {}

class NOT-SET is Nil is export(:NOT-SET) {
    method Bool { False }
}

subset BasicType
    is export
    of Mu
    where { (my Mu $dc := $_<>) =:= Any
                || $dc =:= Mu
                || ($dc ~~ Numeric | Stringy | Dateish | Bool)
                || ($dc.HOW ~~ Metamodel::EnumHOW) };

# Ordered hash. I'm avoiding Hash::Ordered from the ecosystem because it is using Proxy and it'd be slower than I wish.
class OHash does Associative does Iterable is export {
    has %!idx{Mu} handles <EXISTS-KEY>;
    has Mu @.keys handles <elems end>;
    has Mu @.values;

    multi method new(*@values) {
        self.CREATE()!STORE(@values)
    }

    method of { Mu }

    method !KEY-POS(Mu \key) {
        %!idx{key} // do {
            my \idx = @!keys.elems;
            @!keys.BIND-POS: idx, key;
            %!idx.BIND-KEY: key, idx;
        }
    }

    method ASSIGN-KEY(Mu \key, Mu \val) is raw {
        @!values.ASSIGN-POS: self!KEY-POS(key), val
    }

    method BIND-KEY(Mu \key, Mu \val) is raw {
        @!values.BIND-POS: self!KEY-POS(key), val
    }

    method AT-KEY(Mu \key) is rw {
        (%!idx.AT-KEY(key) andthen @!values.AT-POS($_))
            // Proxy.new( FETCH => -> $ { Nil },
                          STORE => -> $, \val { self.ASSIGN-KEY(key, val) } )
    }

    method CLEAR {
        %!idx = @!values = @!keys = Empty;
    }

    method !STORE(@values) {
        my $iter := @values.iterator;
        loop {
            given $iter.pull-one {
                last if $_ =:= IterationEnd;
                when Pair {
                    self.ASSIGN-KEY(.key, .value);
                }
                when Failure {
                    .throw
                }
                default {
                    my \next-val = $iter.pull-one;
                    if next-val =:= IterationEnd  {
                        X::Hash::Store::OddNumber.new(:found(@!values.elems), :last($_)).throw
                    }
                    self.ASSIGN-KEY($_, next-val);
                }
            }
        }
        self
    }

    method STORE(::?CLASS:D: *@values) {
        self.CLEAR;
        self!STORE(@values)
    }

    method pairs is raw handles <iterator List Slip Array Hash> {
        (^@!keys.elems).map({ Pair.new(@!keys[$_], @!values[$_]) })
    }

    method antipairs is raw {
        (^@!keys.elems).map({ Pair.new(@!values[$_], @!keys[$_]) })
    }

    class KVIter does Iterator {
        has @!keys is built(:bind);
        has @!values is built(:bind);
        has $!end = @!keys.end;
        has $!pos = 0;
        has $!is-key = False;

        method pull-one is raw {
            return IterationEnd if $!pos > $!end;
            ($!is-key = !$!is-key) ?? @!keys.AT-POS($!pos) !! @!values.AT-POS($!pos++)
        }
    }

    method kv {
        Seq.new: KVIter.new(:@!keys, :@!values)
    }

    multi method Bool(::?CLASS:D:) { ? @!keys }

    method gist {
        '{' ~ self.pairs.map( *.gist).join(", ") ~ '}'
    }

    method Str {
        self.pairs.join(" ")
    }

    method raku {
        self.perlseen(self.^name, {
            ~ self.^name
                ~ '.new('
                ~ self.pairs.map({$_<>.perl}).join(',')
                ~ ')'
        })
    }
}

sub xml-implicit-value(Mu \value) is export { value but IsImplicitValue }