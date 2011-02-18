#!/usr/bin/env perl
use XML::SAX;
use perl5i::2;
# use modern::perl; # This is throwing an error today, dunno what's up. 

my $handler = TestSAXHandler->new();
my $parser = XML::SAX::ParserFactory->parser(
    Handler => $handler
);

my $a_hashref = $parser->parse_uri("/Users/nick/Documents/Code/complete albums/testdata.xml");

say $a_hashref->keys->join("\n");

package TestSAXHandler;
use base qw(XML::SAX::Base);
use perl5i::2;
# use modern::perl;

# state vars
my @element_stack; # Current element. Unshift on start, shift on end.
my $inside_tracks_dict; # 0 if never, 1 if currently, -1 if exited. Turn on when characters, @element_stack[0] eq 'key', and data eq Tracks. Turn off when @key_stack->shift eq 'Tracks', which will happen one of the times when we end_element and LocalName eq 'dict'.
my $inside_track; # set to 1 when $inside_tracks_dict = 1, $inside_track = 0, start_element, LocalName eq 'dict', and @key_stack[0] ne Tracks. Set to 0 when end_element, LocalName eq 'dict', and $inside_track = 1.
my @key_stack; # Unshift when you see characters and $element_stack[0] eq key. Shift when you end_element, LocalName isn't key, and $previous_completed_tag eq key. no, wait, that's not it....
my @data_structure_stack; # Filled with anonymous hashes. unshift when you start_element an array, dict, or plist. shift when you end_element an array, dict, or plist. This isn't going to be strictly necessary here, but it'll be useful for future plist parsing if I ever need any. 
my %current_track; # Count on it being an empty hash at start of track; set it to an empty track when you write the track to an album. 
# contents: 
    # Name
    # Artist
    # Album
    # Total Time
    # Track Number
    # Track Count
    # Disc Number
    # Compilation

# persistent data vars
my %albums;
# contents:
# album_ID (artist|compilation)_name_disc# (disc# = 0 if absent)
    # Artist
    # Compilation (often absent)
    # Album
    # Total Time (in milliseconds)
    # Track Count
    # \@tracks_seen

sub write_track {
    my ($self, $track) = @_;
    return unless # Get metrics. Most common goes on top.
        exists($track->{Track Count}) && 
        exists($track->{Track Number}) &&
        exists($track->{Album}) &&
        exists($track->{Artist};
    my $artist_or_comp = $track->{Compilation} || $track->{Artist};
    my $album_ID;
    if ( exists($track->{Disc Number}) ) 
    {
        $album_ID = $artist_or_comp . '_' . $track->{Album} . '_' . $track->{Disc Number};
    }
    else
    {
        $album_ID = $artist_or_comp . '_' . $track->{Album} . '_0';
    }
    # First, the easy ones
    for my $attribute ('Artist', 'Album', 'Track Count', 'Compilation', 'Disc Number')
    {
        $albums{$album_ID}{$attribute} = $track->{$attribute} || 0;
    }
    # Then the more complicated ones
    $albums{$album_ID}{Total Time} += $track->{Total Time};
    $albums{$album_ID}{tracks_seen}[$track->{Track Number} - 1] = 1;
    # And... that should be it. 
}


sub start_element {
    my ($self, $element_structure) = @_;
    
    @element_stack->unshift($element_structure->{'LocalName'});
    
    # Add to @data_structure_stack
    if ($element_structure->{'LocalName'} eq 'dict' || 'plist' || 'array')
    {
        @data_structure_stack->unshift(
            { 
            name => $key_stack[0] || 'plist', 
            type => $element_structure->{'LocalName'} 
            }
        );
    }
}

sub end_element {
    my ($self, $element_structure) = @_;
    
    @element_stack->shift;
    
    # Shift from @data_structure_stack
    if ($element_structure->{'LocalName'} eq 'plist') {}
    else if ($element_structure->{'LocalName'} eq 'dict' || 'array')
    {
        @key_stack->shift if 
            ($data_structure_stack[1]->{type} eq 'dict') and 
            ($key_stack[0] eq $data_structure_stack[0]->{name});
        @data_structure_stack->shift;
    }
    else if ( 
        ($element_structure->{'LocalName'} ne 'key') and 
        ($data_structure_stack[0]->{type} eq 'dict')
    )
    {
        @key_stack->shift;
    }
    

}

sub characters {
    my ($self, $characters_structure) = @_;
    
    # Add to @key_stack
    if ($element_stack[0] eq 'key')
    {
        @key_stack->unshift($characters_structure->{'Data'});
    }
}

sub start_document{
}

sub end_document {
#     my $outputstring = %keys_seen->keys->join(", ");
#     return $outputstring;
    return \%albums;
}

1;
