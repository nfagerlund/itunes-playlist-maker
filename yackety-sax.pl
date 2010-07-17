#!/usr/bin/env perl





use perl5i::2;
use Modern::Perl;
use XML::SAX;
# use SaxTrackHandler; HURF DURF, not needed. 



my $parser = XML::SAX::ParserFactory->parser( Handler => SaxTrackHandler->new() );
$parser->parse_uri("/Users/nick/Desktop/complete albums/testdata.xml");


package SaxTrackHandler;


# 	use perl5i::2; Uh, not for now? Let's try that again. 
	use Modern::Perl;
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
	
	my $last_element = '';
	my $current_element = '';
	my $current_key = '';
	my @dict_state = (); # Push key names onto me when we enter a dict. Once we pop Tracks, we can kill the whole project. Maybe. If it's possible. 
	my %current_track_record = (); 
	
	has 'ArtistAlbumsShelf', is => 'ro', isa => 'HashRef';
	has 'CompilationsShelf', is => 'ro', isa => 'HashRef';
	# re-enable these as soon as you're ready to start doing anything interesting w/ this data. 
	# Also, is there any way we can get this unified? Geez. 
	# Maybe preserve the "compilations" flag and put them all under an artist called "various."
	
	sub start_element {
		my ($self, $element_structure) = @_;
		$current_element = $element_structure->{'LocalName'};
		if ($current_element eq 'dict') {
			if ($last_element eq 'plist') {
				push(@dict_state, 'plist');
			}
			else {
				push(@dict_state, $current_key);
			}
		}

			
			
	}
		
		

	
	
	sub characters {
		my ($self, $data_hashref) = @_;
		# say $data_hashref->{'Data'};
		given ($current_element) {
			when ('key') {
				$current_key = $data_hashref->{'Data'};
			}
			when ('dict') { 
				return; # Because I think there's a bunch of whitespace I'd like to avoid trying to call a hash ref on. 
			}
			default {
				return unless $dict_state[1] eq 'Tracks';
				$current_track_record{$current_key} = $data_hashref->{'Data'};
			}
		}
		
		
	}
	
	
	sub end_element {
		my ($self, $element_structure) = @_;
		$last_element = $element_structure->{'LocalName'};
		$current_element = '';
		
		given ($last_element) {
			# special cases for the empty values:
			when ('true') {
				$current_track_record{$current_key} = 'true';
			}
			when ('false') {
				$current_track_record{$current_key} = '';
			}
			when ('dict') {
				my $just_finished_dict = pop(@dict_state);
				# If $just_finished_dict eq 'Tracks', we fuckin' bail, except I don't know how to do that yet. 
				# Else (i.e. $just_finished_dict =~ /\d+/ and $dict_state[-1] eq 'Tracks'), we have a complete track record! Check for sanity per the old meatpacking loop, and put it on the shelf if it passes. Finally, set %current_track_record = ().
				
				if ($just_finished_dict =~ /\d+/ and $dict_state[-1] eq 'Tracks' {
					return unless ( $current_track_record{'Album'} and $current_track_record{'Track Count'} and $current_track_record{'Track Count'} );
					
				}
			}
		}
		
	}
	
# 	
# 	
	
	

