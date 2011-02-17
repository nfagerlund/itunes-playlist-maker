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
my $integercount = 0; 
my @elementstack = ();

sub start_element {
    my ($self, $element_structure) = @_;
    $elementcount += 1;
    $integercount += 1 if $element_structure->{'LocalName'} eq 'integer';
    # This works.
}

sub end_element {}

sub characters {
    my ($self, $characters_structure) = @_;
    say "some nonsense" if $characters_structure->{'Data'} eq 'Brighter Days';
}

sub end_document {
    my $outputstring = $elementcount . " elements total and " . $integercount . " integers. Yay.";
    return $outputstring;
    # This still works. 
}

1;
