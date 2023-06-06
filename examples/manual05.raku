use v6.e.PREVIEW;
use LibXML::Class;

class Record {
    has DateTime:D $.when = DateTime.now;
    has Str:D $.what is required;
}

class Registry is xml-element {
    has Record:D $.rec is required;
}

my $reg = Registry.new: rec => Record.new(:what('record description'));

my $serialized = $reg.to-xml;

say $serialized.Str(:format);

my $reg2 = Registry.from-xml: $serialized.Str;

dd $reg2;