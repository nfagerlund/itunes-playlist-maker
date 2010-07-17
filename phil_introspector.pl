#!/usr/bin/env perl





use perl5i::2;
use Modern::Perl;
use XML::SAX;
# use SaxTrackHandler; HURF DURF, not needed. 

my %ArtistAlbums;
my %Compilations;

# my $parser = XML::SAX::ParserFactory->parser( Handler => SaxTrackHandler->new(ArtistAlbumsShelf => \%ArtistAlbums, CompilationsShelf => \%Compilations));

my $handler = SaxTrackHandler->new(ArtistAlbumsShelf => \%ArtistAlbums, CompilationsShelf => \%Compilations);


my $metainstance = $handler->meta();
my $metaclass = SaxTrackHandler->meta();
say "attributes: ";
say $metainstance->superclasses();

package SaxTrackHandler;


# 	use perl5i::2; Uh, not for now? Let's try that again. 
	use Modern::Perl;
	use XML::SAX::Base;
	use Moose;
# 	use XML::Filter::BufferText;
	extends qw( Moose::Object XML::SAX::Base ); # This MIGHT be necessary? 
# 	extends 'XML::SAX::Base';
	# But I like this better because I distrust multi-parent households. We'll have to introspect later and see if my fave version actually works. 
	
	
	my $last_element = '';
	my $current_element = '';
	my $current_key = '';
	my @dict_state = (); # Push key names onto me when we enter a dict. Once we pop Tracks, we can kill the whole project. Maybe. If it's possible. 
	my %current_track_record = (); 
	
	# Is all the above scoped to the specific object instance? I can't tell! Ask Schwern. 
	
	has 'ArtistAlbumsShelf', is => 'ro', isa => 'HashRef';
	has 'CompilationsShelf', is => 'ro', isa => 'HashRef';
	
	sub start_element {
	}
		
		

	
	
	sub characters {
	}
	
	
	sub end_element {}
	
# 	
# 	
	
	

