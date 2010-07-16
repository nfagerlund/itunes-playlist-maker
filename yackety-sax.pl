#!/usr/bin/env perl





use perl5i::2;
use XML::SAX;
# use SaxTrackHandler; HURF DURF, not needed. 



my $parser = XML::SAX::ParserFactory->parser( Handler => SaxTrackHandler->new() );
$parser->parse_uri("/Users/nick/Desktop/complete albums/testdata.xml");


package SaxTrackHandler;


# 	use perl5i::2; Uh, not for now? Let's try that again. 
	use XML::SAX::Base;
	use Moose;
	use XML::Filter::BufferText;
# 	extends qw( XML::SAX::Base Moose::Object ); This MIGHT be necessary? 
	extends 'XML::SAX::Base';
	# But I like this better. 
	
# 	sub BUILD {
# 		my $self = shift;
# 		return XML::Filter::BufferText->new( Handler => $self );
# 	}
	# Okay, let's see if that works. 
	# It does! At least in the sense that it doesn't break things. I think. We'll have to check efficacy later. 
	
	# has 
	my $last_element;
	
	
	sub start_element {
		my ($self, $element_structure) = @_;
		if  (defined $last_element && $last_element =~ /key/) {
			say "This value is a " . $element_structure->{'LocalName'} . "!";
		}
		
		$last_element = $element_structure->{'LocalName'};
	}
	
# 	sub end_element {
# 		my ($self, $element_structure) = @_;
# 	}
# 	
# 	sub characters {
# 	
# 	}
# 	
# 	
	
	

