#!/usr/bin/env perl
use XML::SAX;
use perl5i::2;
use modern::perl;

my $handler = TestSAXHandler->new();
my $parser = XML::SAX::ParserFactory->parser(
    Handler => $handler
);

$parser->parse_uri("/Users/nick/Documents/Code/complete albums/testdata.xml");

package TestSAXHandler;
use base qw(XML::SAX::Base);
use perl5i::2;
use modern::perl;

sub start_element {
    my ($self, $element_structure) = @_;
    say $element_structure->{'LocalName'};
}

1;
