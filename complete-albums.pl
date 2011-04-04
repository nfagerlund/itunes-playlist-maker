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
# use perl5i::2;
use strict;
use warnings;
use feature ":5.10";

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
    $self->{_itunes_entity_stack} = '';
        # Possible values:
            # 0 - nada.
            # 1 - plist (which is a dict)
            # 2 - tracks (which is a dict)
            # 3 - some_track (which is a dict)
            # 2 - playlists (which is an array of dicts)
            # 3 - some_playlist (which is a dict)
            # 4 - some_playlist_items (which is an array of one-item dicts)
            # 5 - some_individual_playlist_item (which is a dict w/ one item)
    # Scratchpads:
    $self->{_current_item} = {};
    # Final products:
    $self->{_tracks} = {};
        # This is a hash keyed by track ID. Each track is a hash.
    $self->{_playlists} = {};
        # This is a hash keyed by playlist ID. Each playlist is a hash, with a bunch of properties and then a playlist items array. 
    bless( $self, $class );
    return $self;
}

# ---------------

sub start_document {
    # I don't think we need to do anything in here.
}

sub start_element {
    my ($self, $element_structure) = @_;
    # If it's a key or a non-bool scalar value, the only thing that mattered here was putting it on the element stack; we can't do anything with it until we get its characters. The four types of special element require some special processing, though, which is what this is. 
    given ( $element_structure->{LocalName} )
    {
        # Put it on the stack so we know how deep we are.
        unshift( @{ $self->{_element_stack} }, $_);
        # Select based on what we just entered.
        when (/(dict|array)/) 
        { 
            given ( $self->{_itunes_entity_stack} )
            {
                when ('')
                { # We're entering the dict directly under the plist element.
                    $self->{_itunes_entity_stack} = 'plist';
                }
                when ('plist')
                { # We're entering either playlists or tracks.
                    $self->{_itunes_entity_stack} = lc($self->{_key_stack}->[0]);
                }
                when ('tracks')
                { # we're entering some track.
                    $self->{_itunes_entity_stack} = 'some_track';
                }
                when ('some_track') {die "There should be no dicts/arrays inside tracks.";}
                when ('playlists') 
                { # We're entering some playlist.
                    $self->{_itunes_entity_stack} = 'some_playlist';
                }
                when ('some_playlist')
                { # We're entering a playlist items array.
                    $self->{_itunes_entity_stack} = 'some_playlist_items';
                    $self->{_current_item}->{'Playlist Items'} = []; # Initialize items array in the scratchpad. Each playlist should only have one items array.
                }
                when ('some_playlist_items')
                {
                    $self->{_itunes_entity_stack} = 'some_individual_playlist_item';
                }
                when ('some_individual_playlist_item') {die "There should be no dicts/arrays inside a a playlist item.";}
                default {die "Something weird just happened when entering an array or dict.";}
            }
        }
        # Unfortunately, we have to split the logic of writing things to the $self->{_current_item} hash because of the way plists do booleans. 
        # Booleans are always the values to keys, i.e. they always happen inside a dict. Anonymous bools would be silly. 
        when (/true/) { 
            $self->{_current_item}->{ $self->{_key_stack}->[0] } = 1 if ($self->{_itunes_entity_stack} =~ /^some_(track|playlist)$/);
        }
        when (/false/) { # Which I don't think ever happens, btw.
            $self->{_current_item}->{ $self->{_key_stack}->[0] } = 0 if ($self->{_itunes_entity_stack} =~ /^some_(track|playlist)$/);
        }
        default {
            # do nothing aside from the element stack thing above. This includes keys, values, and the root plist element.
        }
    }
}

sub end_element {
    my ($self, $element_structure) = @_;
    # For ease of use:
    # TODO: Turn this into a reference so we're doing less assignment. 
    given ( $element_structure->{LocalName} )
    {
        when (/(dict|array)/)
        {
            # Every type of dict and array that exists should be accounted for as an itunes entity type.
            given ( $self->{_itunes_entity_stack} )
            {
                when ('some_individual_playlist_item')
                {
                    $self->{_itunes_entity_stack} = 'some_playlist_items';
                    shift @{ $self->{_key_stack} };
                }
                when ('some_playlist_items')
                {
                    $self->{_itunes_entity_stack} = 'some_playlist';
                }
                when ('some_playlist')
                {
                    $self->{_itunes_entity_stack} = 'playlists';
                    # Write the playlist and clear the scratchpad.
                    $self->{_playlists}->{ $self->{_current_item}->{'Playlist ID'} } = $self->{_current_item};
                    $self->{_current_item} = {};
                    shift @{ $self->{_key_stack} };
                }
                when ('playlists')
                {
                    $self->{_itunes_entity_stack} = 'plist';
                }
                when ('tracks')
                {
                    $self->{_itunes_entity_stack} = 'plist';
                    shift @{ $self->{_key_stack} };
                }
                when ('some_track')
                {
                    $self->{_itunes_entity_stack} = 'tracks';
                    # Write the track and clear the scratchpad.
                    $self->{_tracks}->{ $self->{_current_item}->{'Track ID'} } = $self->{_current_item};
                    $self->{_current_item} = {};
                    shift @{ $self->{_key_stack} };
                }
                when ('plist')
                {
                    $self->{_itunes_entity_stack} = '';
                }
                
                    
            }
        }
        when ('key') {} # Do nothing, we caught the characters event already.
        when ('plist') {
            die "Tried to exit plist too early!" if ( $self->{_itunes_entity_stack} ne '' );
            # Because we enter and exit the plist entity based on the dict directly inside it, rather than the plist element itself.
        }
        default 
        {
            # We must have just finished a scalar value...
            shift @{ $self->{_key_stack} };
            # ...so get that key off the stack.
        }
    }
    # Get the element off the stack; we're now at a different depth. 
    shift @{ $self->{_element_stack} };
}

sub characters {
    my ($self, $characters_structure) = @_;
    # For ease of use:
    # TODO: Turn this into a reference so we're doing less assignment. 
    # my $data = $characters_structure->{Data};
    
    # We only do work for characters if we're inside a key or a scalar non-bool value; it is literally impossible for there to be other characters events we care about. 
    given ( $self->{_element_stack}->[0] )
    {
        when (undef) {return;} # Let's see if this kills that warning.
        when (/^(dict|array|plist)$/) {return;} # Neither dicts nor arrays nor the root element have any bare character events we care about; they're all hidden away in nested dicts.
        when (/^key$/) { unshift( @{ $self->{_key_stack} }, $characters_structure->{Data} ); }
        default 
        { 
            # Must be a value associated with a key. But...
            if ( $self->{_itunes_entity_stack} eq 'some_individual_playlist_item' )
            { # Maybe we're in a playlist item! In which case, append it.
                die "Something weird happened in a playlist items array!" unless ($self->{_key_stack}->[0] eq 'Track ID');
                # push( @{ $self->{_current_item}->{'Playlist Items'} }, $characters_structure->{Data} );
            } 
            else { $self->{_current_item}->{ $self->{_key_stack}->[0] } = $characters_structure->{Data}; } # Nope, as per normal.
        } 
    }
}


# Time to clean up:

sub end_document {
    my $self = shift;
    # The parser will bubble up the return value of end_document and return it as the result of the parse method.
    return { tracks => $self->{_tracks}, playlists => $self->{_playlists} };
}

1;
