use v6.e.PREVIEW;
use LibXML::Class;
use LibXML::Class::Config :types;

class Record is xml-element {
    has Str:D $.data is required;
    submethod TWEAK {
        say "+ record";
    }
}

class Root is xml-element {
    has Record:D $.record is required;
    submethod TWEAK {
        say "+ root";
    }
}

my $root = Root.new: record => Record.new(:data("some data"));

say "--- deserializing";
my $root-copy = Root.from-xml: $root.to-xml.Str, :config( severity => STRICT );
say "--- deserialized";
say $root-copy.record;
say "--- all done";