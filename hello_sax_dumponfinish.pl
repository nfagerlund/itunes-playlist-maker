#!/usr/bin/env perl
use XML::SAX;
use perl5i::2;
use modern::perl;

my $handler = TestSAXHandler->new();
my $parser = XML::SAX::ParserFactory->parser(
    Handler => $handler
);

my $a_number = $parser->parse_uri("/Users/nick/Documents/Code/complete albums/testdata.xml");

say $a_number;

package TestSAXHandler;
use base qw(XML::SAX::Base);
use perl5i::2;
use modern::perl;

my $elementcount = 0;

sub start_element {
    my ($self, $element_structure) = @_;
    $elementcount += 1;
}

sub end_document {
    say $elementcount . " elements total. Yay.";
    return $elementcount;
    
}

1;
