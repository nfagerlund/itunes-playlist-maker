#!/usr/bin/env perl
use XML::SAX;
use perl5i::2;
use modern::perl;

my $handler = TestSAXHandler->new();
my $parser = XML::SAX::ParserFactory->parser(
    Handler => $handler
);

my $a_number = $parser->parse_uri("/Users/nick/Documents/Code/complete albums/testdata.xml");

say $a_number; # This doesn't work! 

package TestSAXHandler;
use base qw(XML::SAX::Base);
use perl5i::2;
use modern::perl;

my $elementcount = 0;

sub start_element {
    my ($self, $element_structure) = @_;
    $elementcount += 1;
    if ($element_structure->{'LocalName'} eq 'integer')
    {
        return "OK, that is an integer and it's time to bail. " . $elementcount . " elements before death, and we shouldn't see anything in the end_document method.";
    }
}

sub end_document {
    # say $elementcount . " elements total. Yay.";
    # return $elementcount;
    
}

1;
