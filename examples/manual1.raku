use v6.e.PREVIEW;
use LibXML::Class;
use LibXML::Class::Config :types;

class Record is xml-element {
    has Str:D $.data is required;
}

class Root is xml-element {
    has Record:D $.record is required;
}

my $root = Root.new: record => Record.new(:data("some data"));
say $root.to-xml.Str(:format);

my $root-copy = Root.from-xml: $root.to-xml.Str, :config( severity => STRICT );

dd $root;
dd $root-copy;