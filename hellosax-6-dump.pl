#!/usr/bin/env perl
use XML::SAX;
use perl5i::2;
# use modern::perl; # This is throwing an error today, dunno what's up. 

my $handler = TestSAXHandler->new();
my $parser = XML::SAX::ParserFactory->parser(
    Handler => $handler
);

my $a_hashref = $parser->parse_uri("/Users/nick/Documents/Code/complete albums/testdata.xml");

say $a_hashref->keys->join(', ');

package TestSAXHandler;
use base qw(XML::SAX::Base);
use perl5i::2;
# use modern::perl;

my $elementcount = 0;
my $integercount = 100; 
my @elementstack;
my %keys_seen;

sub start_element {
    my ($self, $element_structure) = @_;
    @elementstack->unshift($element_structure->{'LocalName'});
}

sub end_element {
    @elementstack->shift;
}

sub start_document{
}

sub characters {
    my ($self, $characters_structure) = @_;
    if ($elementstack[0] eq 'key')
    {
        $keys_seen{$characters_structure->{'Data'}} ||= 1;
    }
}

sub end_document {
#     my $outputstring = %keys_seen->keys->join(", ");
#     return $outputstring;
    return \%keys_seen;
}

1;
