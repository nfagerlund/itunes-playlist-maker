#!/usr/bin/env perl

# usage: 
# complete-albums.pl [<itunes library XML file>]

# This program reads the iTunes music library XML file (or a copy of one supplied
# on the command line), compiles a list of complete albums longer than a certain
# number of minutes, and makes a playlist of those albums using AppleScript.

# TODO: 
# * Remove progress bar, since we'll likely be running from cron. 
# * ...Speed up xml parsing? 

use XML::SAX;
use perl5i::2;


# ------ Configuration -------
$XML::SAX::ParserPackage = "XML::SAX::ExpatXS"; # Choose a SAX parser. This one is fast.
# ----------------------------

# Make a handler object; see comments in the package below. 
my $handler = iTunesSAXHandler->new();
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
my $library = $parser->parse_uri($itunes_XML);

# (BTW, if we need to dump that hash later for examination, say $albums_hashref->mo->perl;)
say $library->mo->perl; # test code; uncomment this to dump the hashref returned by the parse method.
# return; # test code; uncomment this to keep the applescript from being generated. 





# ----------- SAX handler class ---------------

package iTunesSAXHandler;
use base qw(XML::SAX::Base); # Subclassing this gives us hard stuff for free. I'm honestly not sure if we use it, though.
use perl5i::2;

# ---------------

sub new {
    my $class = shift;
    # Get an instance of the superclass:
    my $self = $class->SUPER::new();
    # ...then muck with it.
    # Set up instance variables: SAX means we have to keep track of our own state. 
    # stacks:
    $self->{_element_stack} = [];
    $self->{_key_stack} = [];
    $self->{_data_structure_stack} = [];
    $self->{_itunes_entity_stack} = [];
        # Possible values:
            # plist
            # tracks (which is a dict)
            # some_track (which is a dict)
            # playlists (which is an array of dicts)
            # some_playlist (which is a dict)
            # some_playlist_items (which is an array of one-item dicts)
    # Toggles:
    $self->{_inside_tracks_dict} = 0;
    $self->{_inside_some_track} = 0;
    $self->{_inside_playlists_array} = 0;
    $self->{_inside_some_playlist} = 0;
    $self->{_inside_playlist_items_array} = 0;
    # Scratchpads:
    $self->{_current_item} = {};
    # Final products:
    $self->{_albums} = {};
    $self->{_tracks} = {};
        # This is a hash keyed by track ID. Each track is a hash.
    $self->{_playlists} = {};
        # This is a hash keyed by playlist ID. Each playlist is a hash, with a bunch of properties and then a playlist items array. 
    bless( $self, $class );
    return $self;
}

# ---------------

# Helper methods: 

sub current_data_structure {
    my ($self) = @_;
    if ( defined($self->{_data_structure_stack}->[0]) ) # If we haven't entered a data structure yet, we can't attempt to access keys in a nonexistant hash.
        { return $self->{_data_structure_stack}->[0]->{type}; }
    else { return ''; }
    
}

sub enter_dict {
    my ($self) = @_;
    if ($self->current_data_structure eq 'dict')
    {
        # Named dict. We need to store the name as well as the fact of its existence.
        $self->{_data_structure_stack}->unshift({ name => $self->{_key_stack}->[0], type => 'dict'});
        if ($self->{_itunes_entity_stack}->[0] eq 'tracks')
        {
            # The tracks dict contains a single level of track dicts, none of which contain dicts. If we're inside the tracks dict and we enter a dict, we're entering a track. The keys for tracks will all be \d+, but I think we can ignore that.
            $self->enter_some_track;
        }
        elsif ($self->{_key_stack}->[0] eq 'Tracks')
        {
            # Hey, we're going into the Tracks dict. Pretty much the only dict where we actually READ the name.
            $self->enter_tracks_dict;
        }
    }
    else
    {
        # This is an anonymous dict; we're in an array or in the root of a plist. 
        $self->{_data_structure_stack}->unshift({ name => '', type => 'dict'});
        if ($self->{_itunes_entity_stack}->[0] eq 'playlists')
            { $self->enter_some_playlist; } # Then we're entering a new playlist! 
        elsif ($self->{_itunes_entity_stack}->[0] eq 'some_playlist_items')
            {
                # Then we're inside the Playlist Items array of a playlist, and are entering a dict containing just one key and value (Track ID => #####). 
                # DO SOMETHING (todo)
            }
        else
            { die "Entered unknown anonymous dict!" unless $self->{_itunes_entity_stack}->[0] eq 'plist'; }
    }
}

sub enter_array {
    my ($self) = @_;
    if ($self->current_data_structure eq 'dict')
    {
        # For the purposes of complete_albums.pl, we don't strictly need to separate the logic like this. 
        $self->{_data_structure_stack}->unshift({ name => $self->{_key_stack}->[0], type => 'array'});
        if ($self->{_key_stack}->[0] eq 'Playlists')
        {
            # Hey, we're going into the Playlists array. 
            $self->enter_playlists_array;
        }
        elsif ($self->{_key_stack}->[0] eq 'Playlist Items')
        {
            # Hey, we're going into the playlist items array of some playlist. 
            $self->enter_playlist_items_array;
        }
        else { die "Tried to enter unknown named array " . $self->{_key_stack}->[0]; }
    }
    else
    {
        # We're entering an anonymous array, of which none should actually exist. 
        # $self->{_data_structure_stack}->unshift({ name => '', type => 'array'});
        die "Tried to enter anonymous array, none of which should actually exist.";
    }
}

sub enter_plist {
    my ($self) = @_;
    $self->{_itunes_entity_stack}->unshift('plist');
}
sub exit_plist {
    my ($self) = @_;
    my $exiting = $self->{_itunes_entity_stack}->shift;
    die "Tried to exit plist too early!" unless $exiting eq 'plist';
}
sub enter_tracks_dict {
    my ($self) = @_;
    $self->{_itunes_entity_stack}->unshift('tracks');
}
sub exit_tracks_dict {
    my ($self) = @_;
    my $exiting = $self->{_itunes_entity_stack}->shift;
    die "Tried to exit tracks too early!" unless $exiting eq 'tracks';
}
sub enter_some_track {
    my ($self) = @_;
    $self->{_itunes_entity_stack}->unshift('some_track');
}
sub exit_some_track {
    my ($self) = @_;
    my $exiting = $self->{_itunes_entity_stack}->shift;
    die "Tried to exit some_track too early!" unless $exiting eq 'some_track';
    $self->write_track($self->{_current_item});
    $self->{_current_item} = {};
}
sub enter_playlists_array {
    my ($self) = @_;
    $self->{_itunes_entity_stack}->unshift('playlists');
}
sub exit_playlists_array {
    my ($self) = @_;
    my $exiting = $self->{_itunes_entity_stack}->shift;
    die "Tried to exit playlists too early!" unless $exiting eq 'playlists';
}
sub enter_some_playlist {
    my ($self) = @_;
    $self->{_itunes_entity_stack}->unshift('some_playlist');
}
sub exit_some_playlist {
    my ($self) = @_;
    my $exiting = $self->{_itunes_entity_stack}->shift;
    die "Tried to exit some_playlist too early!" unless $exiting eq 'some_playlist';
    $self->write_playlist($self->{_current_item});
    $self->{_current_item} = {};
}
sub enter_playlist_items_array {
    my ($self) = @_;
    $self->{_itunes_entity_stack}->unshift('some_playlist_items');
}
sub exit_playlist_items_array {
    my ($self) = @_;
    my $exiting = $self->{_itunes_entity_stack}->shift;
    die "Tried to exit some_playlist_items too early!" unless $exiting eq 'some_playlist_items';
}

sub exit_dict {
    my ($self) = @_;
    # Take it off the stack:
    my $erstwhile_structure = $self->{_data_structure_stack}->shift; 
    if ($self->{_inside_tracks_dict} == 1)
    {
        # We're about to leave either a track or the tracks dict itself.
        if ($erstwhile_structure->{name} eq 'Tracks') { $self->exit_tracks_dict; }
        else { 
            # We just left a track. Take note of that, write the track, and blitz the temporary variable.
            $self->exit_some_track;
        }
    }
    elsif ($self->{_inside_playlists_array} == 1)
    {
        # We're about to leave...something. The dicts we can potentially be leaving are an individual playlist, or one of the one-item track ID => #### dicts inside the Playlist Items array of some playlist.
        if ($self->{_inside_playlist_items_array})
        {
            # We just left one of those one-item dicts in the playlist items array
            # DO SOMETHING (todo)
        }
        else
        {
            # We just left some playlist completely, and will soon be moving on to the next playlist. 
            $self->exit_some_playlist;
        }
    }

}

sub exit_array {
    my ($self) = @_;
    # Take it off the stack:
    my $erstwhile_structure = $self->{_data_structure_stack}->shift; 
    if ($erstwhile_structure->{name} eq 'Playlists')
    {
        # Then we just left the whole playlists array.
        $self->exit_playlists_array;
    }
    elsif ($erstwhile_structure->{name} eq 'Playlist Items')
    {
        # Then we just left some playlist's playlist items array.
        $self->exit_playlist_items_array;
    }
    else { die "Exited unknown array!"; }

}

sub write_track {
    my ($self, $track) = @_;
    # Just put it in the hash. 
    $self->{_tracks}->{ $track->{'Track ID'} } = $track;
}

sub write_playlist {
    my ($self, $playlist) = @_;
    # Just put it in the hash. 
    $self->{_playlists}->{ $playlist->{'Playlist ID'} } = $playlist;
}

sub write_value {
    my ($self, $key, $value) = @_;
    $self->{_current_item}->{$key} = $value;
}

# ---------------


sub start_document {
    # I don't think we need to do anything in here.
}

sub start_element {
    my ($self, $element_structure) = @_;
    # For ease of use:
    # TODO: Turn this into a reference so we're doing less assignment. 
    my $localname = $element_structure->{LocalName};
    # Put it on the stack so we know how deep we are.
    $self->{_element_stack}->unshift($localname);
    
    # If it's a key or a non-bool scalar value, the only thing that mattered here was putting it on the element stack; we can't do anything with it until we get its characters. The four types of special element require some special processing, though, which is what this is. 
    given ($localname)
    {
        when (/dict/) { $self->enter_dict; }
        when (/array/) { $self->enter_array; }
        # Unfortunately, we have to split the logic of writing things to the $self->{_current_item} hash because of the way plists do booleans. 
        # Booleans are always the values to keys, i.e. they always happen inside a dict. Anonymous bools would be silly. 
        when (/true/) { 
            $self->write_value( $self->{_key_stack}->[0], 1 ) if ($self->{_inside_some_track} or $self->{_inside_some_playlist});
        }
        when (/false/) { # Which I don't think ever happens, btw.
            $self->write_value( $self->{_key_stack}->[0], 0 ) if ($self->{_inside_some_track} or $self->{_inside_some_playlist});
        }
        when (/plist/) {
            $self->enter_plist;
        }
    }
}

sub end_element {
    my ($self, $element_structure) = @_;
    # For ease of use:
    # TODO: Turn this into a reference so we're doing less assignment. 
    my $localname = $element_structure->{LocalName};
    
    # If we just finished a key, do nothing.
    # If we just finished a value...
    if ($localname ne 'key' and $self->current_data_structure eq 'dict')
        { $self->{_key_stack}->shift; }
        # ...then we have reached the end of a key/value pair and can get that key off the stack, since we're now at the previous level of depth. This applies to dicts and arrays too, so it has to go before the next one. 
    
    # So also, if we just finished an array or a dict, we need to mark that we're now at a different level of data structure. 
    if ($localname eq 'dict')
        { $self->exit_dict; }
    if ($localname eq 'array')
        { $self->exit_array; }
    if ($localname eq 'plist')
        { $self->exit_plist; }
    # Get the element off the stack; we're now at a different depth. 
    $self->{_element_stack}->shift;
}

sub characters {
    my ($self, $characters_structure) = @_;
    # For ease of use:
    # TODO: Turn this into a reference so we're doing less assignment. 
    my $data = $characters_structure->{Data};
    
    # We only do work for characters if we're inside a key or a scalar non-bool value; it is literally impossible for there to be other characters events we care about. 
    given ( $self->{_element_stack}->[0] )
    {
        when (/^(dict|array)$/) {return;} # Neither dicts nor arrays have any bare character events we care about; they're all hidden away in nested dicts.
        when (/^key$/) { $self->{_key_stack}->unshift($data); }
        default 
        { 
            # Must be a value associated with a key. But...
            if ( $self->{_itunes_entity_stack}->[0] eq 'some_playlist_items' )
            { # Maybe we're in a playlist items array! 
                die "Something weird happened in a playlist items array!" unless ($self->{_key_stack}->[0] eq 'Track ID');
                $self->{_current_item}->{'Playlist Items'} //= []; # /# initialize array if undefined.
                $self->{_current_item}->{'Playlist Items'}->push($data);
            } 
            else { $self->write_value( $self->{_key_stack}->[0], $data ); } # Nope, as per normal.
        } 
    }
}


# Time to clean up:

sub end_document {
    my $self = shift;
    print "DONE! Generating applescript...\n"; # goes with the print "." up above in write_track
    # The parser will bubble up the return value of end_document and return it as the result of the parse method.
    return { tracks => $self->{_tracks}, playlists => $self->{_playlists} };
}

1;
