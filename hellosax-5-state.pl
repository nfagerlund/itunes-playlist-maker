#!/usr/bin/env perl
use XML::SAX;
use perl5i::2;
# use modern::perl; # This is throwing an error today, dunno what's up. 

my $handler = TestSAXHandler->new();
my $parser = XML::SAX::ParserFactory->parser(
    Handler => $handler
);

my $a_number = $parser->parse_uri("/Users/nick/Documents/Code/complete albums/testdata.xml");

say $a_number;

package TestSAXHandler;
use base qw(XML::SAX::Base);
use perl5i::2;
# use modern::perl;

my $elementcount = 0;
my $integercount = 100; 
my @elementstack;
$elementstack[0] = 'test';
$elementstack[1] = 'item';
$elementstack[2] = 'fake';

sub start_element {
    my ($self, $element_structure) = @_;
    $elementcount += 1;
    $integercount += 1 if $element_structure->{'LocalName'} eq 'integer';
    # This works.
}

sub end_element {}

sub start_document{
    @elementstack->push("less-fakey");
}

sub characters {
    my ($self, $characters_structure) = @_;
    if ($characters_structure->{'Data'} eq 'Brighter Days')
    {
        @elementstack->push("extra-fakey");
        my $obvioustempvar = join(', ', @elementstack);
        say "fakie" . $integercount . $elementstack[0] ;
        # This totally acts like I never assigned anything to the array up there! But if I try to not declare it in the scope above, I get a compilation error! So wtf? 
    }
}

sub end_document {
    my $outputstring = $elementcount . " elements total and " . $integercount . " integers. Yay.";
    return $outputstring;
    # This still works. 
    # Oh, remember to check: can I return an arrayref or hashref?
}

1;
