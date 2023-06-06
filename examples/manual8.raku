use v6.e.PREVIEW;
use LibXML::Class;

class Ref is xml-element<ref> {
    has Str:D $.ISBN is required is xml-element;
    has Int:D $.page is required is xml-element;
}

class Index is xml-element('index', :sequence( Ref, :idx(Int:D) )) {
    has Str:D $.title is required;
}

my $index = Index.new: title => "Experimental";

$index.push: 42;

$index.push: Ref.new(:ISBN<1-2-FAKE>, :page(10));
$index.push: Ref.new(:ISBN<3-4-MOCKED>, :page(1001));

say $index.to-xml.Str(:format);