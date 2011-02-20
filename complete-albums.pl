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
# * Rename the file. Move the repo around. 

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
# say $albums_hashref->mo->perl; # test code; uncomment this to dump the hashref returned by the parse method.
# return; # test code; uncomment this to keep the applescript from being generated. 

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
    # A record_wad is either the set of all compilations or the set of all albums by a given artist. It is a hashref containing albums, each of which contains at least one disc, which , arranged in a nested hash
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
# Then, write to the filehandle and close it out. 
# open my $osa, "|osascript";
# say $osa $applescript_string;
# close $osa;

say $applescript_string; # test code; uncomment to dump the applescript. 




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
        # We need to store the name of the dict as well as the fact of its existence.
        @data_structure_stack->unshift({ name => $key_stack[0], type => 'dict'});
        if ($inside_tracks_dict == 1)
        {
            # The tracks dict contains a single level of track dicts, none of which contain dicts. If we're inside the tracks dict and we enter a dict, we're entering track. The keys for tracks will all be \d+, but I think we can ignore that.
            $inside_some_track = 1;
        }
        elsif ($key_stack[0] eq 'Tracks')
        {
            # Hey, we're going into the Tracks dict. Pretty much the only dict where we actually READ the name.
            $inside_tracks_dict = 1;
        }
    }
    else
    {
        # This is an anonymous dict; we're in an array or in the root of a plist. 
        @data_structure_stack->unshift({ name => '', type => 'dict'});
    }
}

sub enter_array {
    my ($self) = @_;
    if ($self->in_a_dict)
    {
        # For the purposes of complete_albums.pl, we don't strictly need to separate the logic like this. 
        @data_structure_stack->unshift({ name => $key_stack[0], type => 'array'});
    }
    else
    {
        @data_structure_stack->unshift({ name => '', type => 'array'});
    }
}

sub exit_dict_or_array {
    my ($self) = @_;
    # Take it off the stack:
    my $erstwhile_structure = @data_structure_stack->shift; 
    if ($inside_tracks_dict == 1)
    {
        # We're about to leave either a track or the tracks dict itself.
        if ($erstwhile_structure->{name} eq 'Tracks') { $inside_tracks_dict = -1; }
        else { 
            # We just left a track. Take note of that, write the track, and blitz the temporary variable.
            $inside_some_track = 0; 
            $self->write_track(\%current_track);
            %current_track = ();
        }
    }
}

# Once we know everything about the track in %current_track, we can write its info to its album. 
sub write_track {
    my ($self, $track) = @_;
    # We check for album completeness in two steps. The first check, here, doesn't bother writing tracks that are obviously not in a complete album. The other check happens in the ALBUMS: loop.
    return unless (# Get metrics. Most common goes on top.
        exists($track->{'Track Count'}) && 
        exists($track->{'Track Number'}) &&
        exists($track->{Album}) &&
        exists($track->{Artist})
    );
    # Instead of using nested hashes, we're currently using an album ID string to key a single level of hashes. I don't think this is as fast as it could be.
    my $artist_or_comp = $track->{Compilation} ? 'Compilation' : $track->{Artist};
    my $disc_or_0 = $track->{'Disc Number'} || 0;
    # Bring the destination hashref to life if necessary.
    $albums{$artist_or_comp}{$track->{Album}}{$disc_or_0} //= {}; #/# nonsense comment for bbedit
    # For convenience: 
    my $album = $albums{$artist_or_comp}{$track->{Album}};
    my $disc = $albums{$artist_or_comp}{$track->{Album}}{$disc_or_0}; 
    
    # First, write the easy attributes:
    # Album attributes:
    for my $attribute ('Artist', 'Album', 'Compilation')
    {
        $album->{$attribute} = $track->{$attribute} || 0;
        # This is safer than it looks, because we already checked to make sure these are filled with something. So we won't get artist 0 for something that had artist null, because it won't have gotten this far anyway. 
    }
    # Disc attributes:
    for my $attribute ('Track Count', 'Disc Number')
    {
        $disc->{$attribute} = $track->{$attribute} || 0;
    }
    # Then the more complicated ones:
    $disc->{'Total Time'} += $track->{'Total Time'};
    $disc->{tracks_seen}[$track->{'Track Number'} - 1] = 1;
    # And... that should be it. 
    print "."; # just for good measure
}



# ---------------


sub start_element {
    my ($self, $element_structure) = @_;
    # If we're done with what we care about, then bye. 
    return if $inside_tracks_dict == -1;
    # For ease of use:
    # TODO: Turn this into a reference so we're doing less assignment. 
    my $localname = $element_structure->{LocalName};
    # Put it on the stack so we know how deep we are.
    @element_stack->unshift($localname);
    
    # If it's a key or a non-bool scalar value, the only thing that mattered here was putting it on the element stack; we can't do anything with it until we get its characters. The four types of special element require some special processing, though, which is what this is. 
    given ($localname)
    {
        when (/dict/) { $self->enter_dict; }
        when (/array/) { $self->enter_array; }
        # Unfortunately, we have to split the logic of writing things to the %current_track hash because of the way plists do booleans. 
        # Booleans are always the values to keys, i.e. they always happen inside a dict. Anonymous bools would be silly. 
        when (/true/) { 
            $current_track{$key_stack[0]} = 1 if ($inside_some_track);
        }
        when (/false/) {
            $current_track{$key_stack[0]} = 0 if ($inside_some_track);
        }
    }
}

sub end_element {
    my ($self, $element_structure) = @_;
    # If we're done with what we care about, then bye. 
    return if $inside_tracks_dict == -1;
    # For ease of use:
    # TODO: Turn this into a reference so we're doing less assignment. 
    my $localname = $element_structure->{LocalName};
    
    # If we just finished a key, do nothing.
    # If we just finished a value...
    if ($localname ne 'key' and $self->in_a_dict)
        { @key_stack->shift; }
        # ...then we have reached the end of a key/value pair and can get that key off the stack, since we're now at the previous level of depth. This applies to dicts and arrays too, so it has to go before the next one. 
    
    # So also, if we just finished an array or a dict, we need to mark that we're now at a different level of data structure. 
    if ($localname eq 'dict' or $localname eq 'array')
        { $self->exit_dict_or_array; }
    
    # Get the element off the stack; we're now at a different depth. 
    @element_stack->shift;
}

sub characters {
    my ($self, $characters_structure) = @_;
    # If we're done with what we care about, then bye. 
    return if $inside_tracks_dict == -1;
    # For ease of use:
    # TODO: Turn this into a reference so we're doing less assignment. 
    my $data = $characters_structure->{Data};
    
    # We only do work for characters if we're inside a key or a scalar non-bool value; it is literally impossible for there to be other characters events we care about. 
    if ($self->in_a_dict) # then it's a key or a value, by definition.
    {
        if ($element_stack[0] eq 'key')
        {  
            @key_stack->unshift($data);
        }
        # Note that we only care about scalar values if they're part of a track. Also note that dict elements contain bogus character events consisting of whitespace, so leave those out!
        elsif ($inside_some_track and $element_stack[0] ne 'dict')
        {
            $current_track{$key_stack[0]} = $data;
        }
        # Arrays don't happen in the two places (values inside a track and keys) where we care about characters events, so their bogus whitespace isn't an issue. We'd have to handle it if we were reading real data from arrays. 
    }
}


# Time to clean up:

sub end_document {
    print "DONE! Generating applescript...\n"; # goes with the print "." up above in write_track
    # The parser will bubble up the return value of end_document and return it as the result of the parse method.
    return \%albums;
}

1;
