#!/usr/bin/env perl

# usage: 
# complete-albums.pl [<itunes library XML file>]

# This program reads the iTunes music library XML file (or a copy of one supplied
# on the command line), compiles a list of complete albums longer than a certain
# number of minutes, and makes a playlist of those albums using AppleScript.

# TODO: 
# * Remove progress bar, since we'll likely be running from cron. 
# * Refactor to speed up applescript:
#     * Return a more deeply-nested hash structure from the parse method
#         * This will entail changing the write_track method and the append_applescript_album_fragment function and the loop that figures out whether the album is complete.
#     * group 'duplicate' statements
#         * all tracks whose artist is foo and ( (album is bar and disc number is (baz or qux)) or (album is bats) )
# * ...Speed up xml parsing? 

use XML::SAX;
use perl5i::2;


# ------ Configuration -------
$XML::SAX::ParserPackage = "XML::SAX::ExpatXS"; # Choose a SAX parser. This one is fast.
my $length_threshold = 15; # in minutes. 
my $destination_playlist = "_Complete Albums"; # This can include backslashes and "s if need be; we'll escape it later. 
# ----------------------------

# Make a handler object; see comments in the package below. 
my $handler = TestSAXHandler->new();
# Make a parser object:
my $parser = XML::SAX::ParserFactory->parser(
    Handler => $handler
);
# Find the iTunes library XML file, trick courtesy Doug's iTunes Applescripts.
my $system_reported_itunes_XML = `defaults read com.apple.iApps iTunesRecentDatabasePaths`; 
# returns:
# (
#     "~/Music/iTunes/iTunes Music Library.xml"
# )
$system_reported_itunes_XML =~ s/\(\s*"(.+\.xml)"\s*\)/$1/s;
$system_reported_itunes_XML =~ s/^~/$ENV{HOME}/; 
# But then ignore this if we were passed a file to use:
my $itunes_XML = ($ARGV[0] ? shift : $system_reported_itunes_XML);

# Parse the XML and return a hashref:
my $albums_hashref = $parser->parse_uri($itunes_XML);
# (BTW, if we need to dump that hash later for examination, say $albums_hashref->mo->perl;)

# This function just backslash-escapes double-quotes and backslashes, so our strings stay neatly trapped inside their AppleScript double-quotes.
sub quote_for_applescript {
    my ($str) = @_;
    $str =~ s/(["\\])/\\$1/g;
    return $str;
}

# This will be a string in an AppleScript. Clean it.
$destination_playlist = quote_for_applescript($destination_playlist);

# This variable will contain the entire AppleScript we'll eventually be executing. This primes it with a preamble. 
my $applescript_string = <<EOF;
tell application "TextEdit"
	make new document with properties {name:"Nick's Bitched-Up Progress Meter", text:"Yes, I realize this is completely barbaric. Sorry, Standand Additions' godawful dialog support leaves me no choice. Starting..."}
end tell
on updateProgress(current, total)
	set dialogMessage to "Adding album " & current & " of " & total & " possible"
	tell application "TextEdit" to set text of document "Nick's Bitched-Up Progress Meter" to dialogMessage
end updateProgress
tell application "iTunes"
	if (exists user playlist "$destination_playlist") then
		delete every track of user playlist "$destination_playlist"
	else
		make user playlist with properties {name:"$destination_playlist"}
	end if
	set musicRef to (get some playlist whose special kind is Music) --http://dougscripts.com/itunes/itinfo/playlists02.php
	set destRef to user playlist "$destination_playlist"
EOF
# Notes on that: 
# * I'll probably want to remove the progress meter at some point.
# * This is currently only medium speed -- we're using references to the playlist and the Music library, which speeds it up, but we're adding each album individually, when we should be grouping it by artist or compilation status. The more complex the statement, the faster itunes appears to go. 
# * We delete the whole playlist, then re-build it. Only way to handle cases where someone deleted half an album between runs. 

# These are solely for use in the progress meter. If I strip it out later, these vars can go too. 
my $number_of_possible_complete_albums = @{$albums_hashref->keys};
my $current_possible_complete_album = 1;

# This function adds a single album to the applescript. 
sub append_applescript_album_fragment {
    my ($album) = @_;
    $applescript_string .= "\tduplicate (every track of musicRef whose "; # Note the open-parens here.
    if ($album->{Compilation})
    {
        $applescript_string .= "compilation is true";
    }
    else
    {
        $applescript_string .= q{artist is "} . quote_for_applescript($album->{Artist}) . q{"};
        # Since this isn't Ruby, we can't execute arbitrary code in double-quotes. So it's an append festival.
    }
    $applescript_string .= q{ and album is "} . quote_for_applescript($album->{Album}) . q{"};
    $applescript_string .= " and disc number is " . $album->{'Disc Number'} if $album->{'Disc Number'};
    # Handling multi-disc albums as each album being a different disc seems like the only sane way. 
    $applescript_string .= ") to destRef\n"; # ...and close the parentheses!
}

ALBUMS: for my $album ($albums_hashref->values)
{
    # Update the progress bar whether or not we're actually adding this album. 
    $applescript_string .= "\tmy updateProgress($current_possible_complete_album, $number_of_possible_complete_albums)\n";
    $current_possible_complete_album++;
    # Skip records where we don't even have a long enough tracks_seen array:
    next unless @{ $album->{tracks_seen} } == $album->{'Track Count'};
    # Skip short records: 
    next unless $album->{'Total Time'}/60000 >= $length_threshold;
    # Skip incomplete records: 
    for my $i (0..$album->{tracks_seen}->last_index)
        {  next ALBUMS unless $album->{tracks_seen}->[$i];  }
    # We now know that we're looking at a complete album. Write it. 
    append_applescript_album_fragment($album);
    # test code -- If you want to just print a list of complete albums, uncomment this: 
    # print $album->{Compilation} ? 'Compilation' : $album->{Artist};
    # say ' - ' . $album->{Album} . ' (disc ' . $album->{'Disc Number'} . ')';
}

# Finish the applescript: end the main tell and write to the progress bar one last time. 
$applescript_string .= <<EOF;
end tell
tell application "TextEdit" to set text of document "Nick's Bitched-Up Progress Meter" to "Done! Go ahead and close me."
EOF

# Execute the applescript. 
# Open the osascript command as a filehandle; when you write to this, osascript will receive it as stdin. 
open my $osa, "|osascript";
# Write to the filehandle:
say $osa $applescript_string;
# ...and close it out. 
close $osa;

# say $albums_hashref->mo->perl; # test code; uncomment this to dump the hashref returned by the parse method.





# ----------- SAX handler class ---------------

package TestSAXHandler;
use base qw(XML::SAX::Base); # Subclassing this gives us hard stuff for free. I'm honestly not sure if we use it, though.
use perl5i::2;

# SAX means we have to keep track of our own state:
# stacks:
my @element_stack;
my @key_stack;
my @data_structure_stack;

# Toggles:
my $inside_tracks_dict;
my $inside_some_track;

# Scratchpads:
my %current_track;

# Final products:
my %albums;

# ---------------

# Initialize all those variables to zilch:

sub start_document {
    @element_stack = ();
    @key_stack = ();
    @data_structure_stack = ();
    $inside_tracks_dict = 0;
    $inside_some_track = 0;
    %current_track = ();
    %albums = ();
}

# ---------------

# Helper methods: 

sub in_a_dict {
    my ($self) = @_;
    # We can tell we're in a dict if the top data structure on the stack is of type dict.
    if (
        (@data_structure_stack) # If we haven't entered a data structure yet, we can't attempt to access keys in a nonexistant hash.
        and
        $data_structure_stack[0]->{type} eq 'dict'
    )
    {  return 1;  }
    else {  return 0;  }
}

sub in_an_array {
    # Same thing. Mind, I don't think this'll ever get called. Future-proofing.
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
    if ($self->in_a_dict)
    {
        @data_structure_stack->unshift({ name => $key_stack[0], type => 'dict'});
        if ($inside_tracks_dict == 1)
        {
            # The keys for tracks will all be \d+, but I think we can ignore that.
            $inside_some_track = 1;
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
            $self->write_track(\%current_track);
            %current_track = ();
        }
    }
}



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
    
    @element_stack->shift;
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
        }
        elsif ($inside_some_track and $element_stack[0] ne 'dict')
        {
            $current_track{$key_stack[0]} = $data;
        }
        # else we don't care.
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
    print "."; # just for good measure
}


sub end_document {
    print "DONE! Generating applescript...\n"; # goes with the print "." up above in write_track
    return \%albums;
}

1;
