use v6.e.PREVIEW;
unit class LibXML::Class::Document;

use LibXML::Document;

use LibXML::Class::Config;

has LibXML::Document:D $.libxml-document is required;

has LibXML::Class::Config:D $.config .= global;

# Map unique keys of LibXML elements into LibXML::Class XML representations
has %!node-registry;

proto method parse(|) {*}
multi method parse(::?CLASS:U: LibXML::Class::Config :$config is copy, |c) {
    $config //= LibXML::Class::Config.global;
    my $libxml-config = $config.libxml-config;
    my LibXML::Document:D $libxml-document =
        $libxml-config.class-from(LibXML::Document).parse(config => $config.libxml-config, |c);
    self.new: :$libxml-document, :$config
}
multi method parse(::?CLASS:D: |c) {
    $!libxml-document .= parse(config => $.config.libxml-config, |c);
    self
}