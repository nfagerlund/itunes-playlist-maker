#!/usr/bin/env perl





use perl5i::2;
use Modern::Perl;
use XML::SAX;
# use SaxTrackHandler; HURF DURF, not needed. 



my $parser = XML::SAX::ParserFactory->parser( Handler => SaxTrackHandler->new() );
$parser->parse_uri("/Users/nick/Desktop/complete albums/testdata.xml");


package SaxTrackHandler;


# 	use perl5i::2; Uh, not for now? Let's try that again. 
	use XML::SAX::Base;
	use Moose;
# 	use XML::Filter::BufferText;
# 	extends qw( XML::SAX::Base Moose::Object ); This MIGHT be necessary? 
	extends 'XML::SAX::Base';
	# But I like this better because I distrust multi-parent households. We'll have to introspect later and see if my fave version actually works. 
	
# 	sub BUILD {
# 		my $self = shift;
# 		return XML::Filter::BufferText->new( Handler => $self );
# 	}
	# Okay, let's see if that works. 
	# It does! At least in the sense that it doesn't break things. I think. We'll have to check efficacy later. 
	
	my $last_element;
	my $current_element;
	my $current_key;
	my @dict_state; # Push key names onto me when we enter a dict. Once we pop Tracks, we can kill the whole project. Maybe. If it's possible. 
	
# 	has 'ArtistAlbumsShelf', is => 'ro', isa => 'HashRef';
# 	has 'CompilationsShelf', is => 'ro', isa => 'HashRef';
	# re-enable these as soon as you're ready to start doing anything interesting w/ this data. 
	# Also, is there any way we can get this unified? Geez. 
	# Maybe preserve the "compilations" flag and put them all under an artist called "various."
	
	sub start_element {
		my ($self, $element_structure) = @_;
		$current_element = $element_structure->{'LocalName'};
		given ($current_element) {
			when (/key/) {
				$current_key = '';
				
				
				return;
				
			}
			when (/dict/) {
				
			}
			
			default {
				
			}
		
		}

#		if  ($last_element eq "key") {
			# say "This value is a " . $element_structure->{'LocalName'} . "!";
			
			
		}
		
		
	}
	
	
	sub characters {
		my ($self, $data_hashref) = @_;
		# say $data_hashref->{'Data'};
		$current_key = $data_hashref->{'Data'} if $current_element eq "key";
		
		
	}
	
	
	sub end_element {
		my ($self, $element_structure) = @_;
		
		
		$last_element = $element_structure->{'LocalName'};
		undef $current_element;
	}
	
# 	
# 	
	
	

