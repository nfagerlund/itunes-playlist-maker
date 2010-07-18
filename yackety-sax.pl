#!/usr/bin/env perl


use perl5i::2;
use Modern::Perl;
use XML::SAX;



my %ArtistAlbums;
my %Compilations;




my $parser = 
	XML::SAX::ParserFactory->parser( 
		Handler => SaxTrackHandler->new(ArtistAlbumsShelf => \%ArtistAlbums, CompilationsShelf => \%Compilations)
	);
	
$parser->parse_uri("/Users/nick/Desktop/complete albums/testdata.xml");

# And now some testing code:
say %Compilations->mo->perl;
say "Okay, and now the artist albums: ";
say %ArtistAlbums->mo->perl;







package SaxTrackHandler;
#	use Modern::Perl;
	use perl5i::2;
	use Moose;
	BEGIN { extends 'XML::SAX::Base'; }

# 	use XML::Filter::BufferText;
# 	sub BUILD {
# 		my $self = shift;
# 		return XML::Filter::BufferText->new( Handler => $self );
# 	}
	# Okay, let's see if that works. 
	# It does! At least in the sense that it doesn't break things. I think. We'll have to check efficacy later. 
	
	
	# PUBLIC ATTRIBUTES:
	has 'ArtistAlbumsShelf' => (is => 'ro', isa => 'HashRef');
	has 'CompilationsShelf' => (is => 'ro', isa => 'HashRef');
	
	# PRIVATE ATTRIBUTES:
	has last_element => ( is => 'rw', default => '', init_arg => undef );
	has current_element => ( is => 'rw', default => '', init_arg => undef );
	has current_key => ( is => 'rw', default => '', init_arg => undef );
	has dict_state => ( is => 'rw', default => sub{ [] }, isa => 'ArrayRef', init_arg => undef );
	has active_track_record => ( is => 'rw', default => sub{ {} }, isa => 'HashRef', init_arg => undef );
	
	
	sub start_element {
		my ($self, $element_structure) = @_;
		$self->current_element(
			$element_structure->{'LocalName'}
		);
		if ($self->current_element eq 'dict') {
			if ($self->last_element eq 'plist') {
				$self->dict_state->push('plist');
			}
			else {
				$self->dict_state->push($self->current_key);
			}
		}

			
			
	}
		
		

	
	
	sub characters {
		my ($self, $data_hashref) = @_;
		given ($self->current_element) {
			when ('key') {
				$self->current_key( $data_hashref->{'Data'} );
			}
			when ('dict') { 
				return; # Because I think there's a bunch of whitespace I'd like to avoid trying to do a hash lookup on. 
			}
			default {
				return unless $self->dict_state->[1] eq 'Tracks';
				$self->active_track_record->{$self->current_key} = $data_hashref->{'Data'};
			}
		}
		
		
	}
	
	
	sub end_element {
		my ($self, $element_structure) = @_;
		$self->last_element( $element_structure->{'LocalName'} );
		$self->current_element('');
		
		given ($self->last_element) {
			# special cases for the empty values:
			when ('true') {
				$self->active_track_record->{$self->current_key} = 'true';
			}
			when ('false') {
				$self->active_track_record->{$self->current_key} = '';
			}
			when ('dict') {
				my $just_finished_dict = $self->dict_state->pop;
				# If $just_finished_dict eq 'Tracks', we fuckin' bail, except I don't know how to do that yet. 
				# Else (i.e. $just_finished_dict =~ /\d+/ and $dict_state[-1] eq 'Tracks'), we have a complete track record! Check for sanity per the old meatpacking loop, and put it on the shelf if it passes. Finally, set %active_track_record = ().
				
				if ($just_finished_dict =~ /\d+/ and $self->dict_state->[-1] eq 'Tracks') {
					return unless ( $self->active_track_record->{'Album'} and $self->active_track_record->{'Track Count'} and $self->active_track_record->{'Track Number'} );
					$self->ArtistAlbumsShelf->{ $self->active_track_record{'Artist'} } ||= {};
					my $temp_shelf = ($self->active_track_record->{'Compilation'} ? 
						$self->CompilationsShelf : 
						$self->ArtistAlbumsShelf->{ $active_track_record{'Artist'} }
					);
					my $album = $temp_shelf->{ $self->active_track_record->{'Album'} };
					$album->{tracks_array}[ $self->active_track_record->{'Track Number'} - 1 ] = 1;
					$album->{total_tracks} = $self->active_track_record->{'Track Count'}; 
					$album->{length_in_milliseconds} += $self->active_track_record->{'Total Time'};
					
				}
			}
		}
		
	}
	
# 	
# 	
	
	

