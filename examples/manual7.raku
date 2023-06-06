use v6.e.PREVIEW;
use LibXML::Class;

class References is xml-element( :sequence( :idx(Int:D), :ref(Str:D, :attr<title>) ) ) {
    has Str:D $.title is required;
}

my $refs = References.new: :title('An Article');

$refs.push: 123456;
$refs.push: "3rd Party Article";
$refs.push: "Another Article";
$refs.push: 987654;

say $refs.to-xml.Str(:format);