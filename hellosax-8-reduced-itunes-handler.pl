#!/usr/bin/env perl
use XML::SAX;
use perl5i::2;

$XML::SAX::ParserPackage = "XML::SAX::ExpatXS";
# Oh HOLY FUCK that was fast. 

my $handler = TestSAXHandler->new();
my $parser = XML::SAX::ParserFactory->parser(
    Handler => $handler
);

my $system_reported_itunes_XML = `defaults read com.apple.iApps iTunesRecentDatabasePaths`; # This trick courtesy Doug's iTunes Applescripts, basically. 
$system_reported_itunes_XML =~ s/\(\s*"(.+\.xml)"\s*\)/$1/s;
$system_reported_itunes_XML =~ s/^~/$ENV{HOME}/; 
my $itunes_XML = ($ARGV[0] ? shift : $system_reported_itunes_XML);


my $albums_hashref = $parser->parse_uri($itunes_XML);

say $albums_hashref->mo->perl;

# say "Track names: ";
# say $temp_array->join("\n");

# 
# say $a_hashref->keys->join("\n");

# -----------

package TestSAXHandler;
use base qw(XML::SAX::Base);
use perl5i::2;

# state vars.

# stacks:
my @element_stack;
my @key_stack;
my @data_structure_stack;

# Toggles:
my $inside_tracks_dict;
my $inside_some_track;

# Scratchpads:
my %current_track;

# Products:
my %albums;

# our throwaway var for track names
my @track_names;

# ---------------

sub start_element {
    my ($self, $element_structure) = @_;
    return if $inside_tracks_dict == -1;
    my $localname = $element_structure->{LocalName};
    @element_stack->unshift($localname);
    
    given ($localname)
    {
        when (/dict/) { $self->enter_dict; }
        when (/array/) { $self->enter_array; }
        when (/true/) { 
            # I think it'll always be a value to a key. Can't see any reason to have an anonymous bool. 
            $current_track{$key_stack[0]} = 1 if ($inside_some_track);
            # say $key_stack[0] . ' ' . $current_track{$key_stack[0]}; # test code
        }
        when (/false/) {
            $current_track{$key_stack[0]} = 0 if ($inside_some_track);
        }
    }
}

sub end_element {
    my ($self, $element_structure) = @_;
    return if $inside_tracks_dict == -1;
    my $localname = $element_structure->{LocalName};
    
    given ($localname)
    {
    when (!/key/ and $self->in_a_dict)
        {
            # Then we must have just finished reading a value, and have exited a key/val pair. This should work for dict values too, when we finally exit them.
            @key_stack->shift; continue
        }
    when (/(dict|array)/) 
        { $self->exit_dict_or_array; }
    }
    
    @element_stack->shift; # This should be the last thing we do, so our hungry key method if we decide to make one works the same in characters and end_element.
}

sub characters {
    my ($self, $characters_structure) = @_;
    return if $inside_tracks_dict == -1;
    my $data = $characters_structure->{Data};
    
    
    if ($self->in_a_dict) # then it's a key or a value.
    {
        if ($element_stack[0] eq 'key')
        {  
            @key_stack->unshift($data);
            # say $data if $data eq 'Tracks'; # test code
        }
        elsif ($inside_some_track and $element_stack[0] ne 'dict')
        {
            $current_track{$key_stack[0]} = $data;
            # say $current_track{$key_stack[0]}; # test code
            # say $data;
        }
        # else we don't care.
    }
}

sub in_a_dict {
    my ($self) = @_;
    if (
        (@data_structure_stack)
        and
        $data_structure_stack[0]->{type} eq 'dict'
    )
    {  return 1;  }
    else {  return 0;  }
}

sub in_an_array {
    # Mind, I don't think this'll ever get called. 
    my ($self) = @_;
    if (
        (@data_structure_stack)
        and
        $data_structure_stack[0]->{type} eq 'array'
    )
    {  return 1;  }
    else {  return 0;  }
}

sub enter_dict {
    my ($self) = @_;
    # say $inside_tracks_dict; # testing code
    if ($self->in_a_dict)
    {
        @data_structure_stack->unshift({ name => $key_stack[0], type => 'dict'});
        if ($inside_tracks_dict == 1)
        {
            # The keys for tracks will all be \d+, but I think we can ignore that.
            $inside_some_track = 1;
            # say "Entering track " . $key_stack[0]; # test code
        }
        elsif ($key_stack[0] eq 'Tracks')
        {
            $inside_tracks_dict = 1;
        }
    }
    else
    {
        @data_structure_stack->unshift({ name => '', type => 'dict'});
    }
}

sub enter_array {
    my ($self) = @_;
    if ($self->in_a_dict)
    {
        @data_structure_stack->unshift({ name => $key_stack[0], type => 'array'});
    }
    else
    {
        @data_structure_stack->unshift({ name => '', type => 'array'});
    }
}

sub exit_dict_or_array {
    my ($self) = @_;
    my $erstwhile_structure = @data_structure_stack->shift; 
    if ($inside_tracks_dict == 1)
    {
        if ($erstwhile_structure->{name} eq 'Tracks') { $inside_tracks_dict = -1; }
        else { $inside_some_track = 0; 
            # say "Leaving track " . $erstwhile_structure->{name}; # test code
            $self->write_track(\%current_track);
            %current_track = ();
        }
    }
}

sub write_track {
    my ($self, $track) = @_;
    return unless (# Get metrics. Most common goes on top.
        exists($track->{'Track Count'}) && 
        exists($track->{'Track Number'}) &&
        exists($track->{Album}) &&
        exists($track->{Artist})
    );
    my $artist_or_comp = $track->{Compilation} ? 'Compilation' : $track->{Artist};
    my $album_ID;
    if ( exists($track->{'Disc Number'}) ) 
    {
        $album_ID = $artist_or_comp . '_' . $track->{Album} . '_' . $track->{'Disc Number'};
    }
    else
    {
        $album_ID = $artist_or_comp . '_' . $track->{Album} . '_0';
    }
    # First, the easy ones
    for my $attribute ('Artist', 'Album', 'Track Count', 'Compilation', 'Disc Number')
    {
        $albums{$album_ID}{$attribute} = $track->{$attribute} || 0;
        # This is safer than it looks, because we already checked to make sure these are filled with something. So we won't get artist 0 for something that had artist null, because it won't have gotten this far anyway. 
    }
    # Then the more complicated ones
    $albums{$album_ID}{'Total Time'} += $track->{'Total Time'};
    $albums{$album_ID}{tracks_seen}[$track->{'Track Number'} - 1] = 1;
    # And... that should be it. 
}


sub start_document {
    @element_stack = ();
    @key_stack = ();
    @data_structure_stack = ();
    $inside_tracks_dict = 0;
    $inside_some_track = 0;
    %current_track = ();
    %albums = ();
    
    
}

sub end_document {
#     my $outputstring = %keys_seen->keys->join(", ");
#     return $outputstring;
    # return \%albums; # or.... something. haven't identified it yet. 
    return \%albums;
}

1;
