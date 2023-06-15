use v6.e.PREVIEW;
unit role LibXML::Class::HOW::Configurable;

# Defaults for configuration class

has $!xml-config-defaults;

method xml-set-config-defaults(Mu, %xml-config-defaults) {
    $!xml-config-defaults //= %xml-config-defaults
}

method xml-config-defaults(Mu) { $!xml-config-defaults // %() }

# Copyright (c) 2023, Vadim Belman <vrurg@cpan.org>
#
# See the LICENSE file for the license