#!/usr/bin/env perl
use XML::SAX;
use perl5i::2;


my $handler = TestSAXHandler->new();
my $parser = XML::SAX::ParserFactory->parser(
    Handler => $handler
);


my $temp_array = $parser->parse_uri("/Users/nick/Documents/Code/complete albums/testdata.xml");
say "Track names: ";
say $temp_array->join("\n");

# 
# say $a_hashref->keys->join("\n");

# -----------

package TestSAXHandler;
use base qw(XML::SAX::Base);
use perl5i::2;

# reduced state vars
my @element_stack;
my @key_stack;
my @data_structure_stack;
my $inside_tracks_dict;
my $inside_some_track;

# our throwaway var for track names
my @track_names;

# ---------------

sub start_element {
    my ($self, $element_structure) = @_;
    my $localname = $element_structure->{LocalName};
    @element_stack->unshift($localname);
    
    given ($localname)
    {
        when (/dict/) { $self->enter_dict; }
        when (/array/) { $self->enter_array; }
        when (/(true|false)/) { 
            # do something, because we won't get a characters event. 
            # And I think it'll always be a value to a key. Can't see any reason to have an anonymous bool. 
            say "found a bool $_"; # test code
        }
    }
}

sub end_element {
    my ($self, $element_structure) = @_;
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
    my $data = $characters_structure->{Data};
    
    
    if ($self->in_a_dict) # then it's a key or a value.
    {
        if ($element_stack[0] eq 'key')
        {  
            @key_stack->unshift($data);
            say $data if $data eq 'Tracks'; # test code
        }
        elsif (!defined($key_stack[0]))
        {  say $data;  }        
        else
        {
            @track_names->push($data) if $key_stack[0] eq 'Name';
        }
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
            say "Entering track " . $key_stack[0]; # test code
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
            say "Leaving track " . $erstwhile_structure->{name}; # test code
        }
    }
}


sub start_document {
    @element_stack = ();
    @key_stack = ();
    @data_structure_stack = ();
    $inside_tracks_dict = 0;
    $inside_some_track = 0;
#     %current_track = ();
#     %albums = ();
    
    
}

sub end_document {
#     my $outputstring = %keys_seen->keys->join(", ");
#     return $outputstring;
    # return \%albums; # or.... something. haven't identified it yet. 
    return \@track_names;
}

1;
