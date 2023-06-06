use v6.e.PREVIEW;
use LibXML::Class;
use LibXML::Class::Config :types;

class Foo is xml-element(:implicit) {
    has Int $.foo;
    has Str $.bar is xml-element;
}

my $foo = Foo.new: :42foo, :bar('textual value');

say $foo.to-xml.Str(:format);