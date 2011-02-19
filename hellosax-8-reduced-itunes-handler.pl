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
my $inside_some_track; # dunno if I'll use either of those. 

# our throwaway var for track names
my @track_names;

# ---------------

sub start_element {
    my ($self, $element_structure) = @_;
    my $localname = $element_structure->{LocalName};
    @element_stack->unshift($localname);
    
    given ($localname)
    {
        when (/dict/) { @data_structure_stack->unshift({ name => 'dummy', type => 'dict'}); }
        when (/array/) { @data_structure_stack->unshift({ name => 'dummy', type => 'array'}); }
        when (/(true|false)/) { 
            #do something, because we won't get a characters event. 
            say "found a bool $_";
        }
    }
}

sub end_element {
    my ($self, $element_structure) = @_;
    my $localname = $element_structure->{LocalName};
    @element_stack->shift;
    
    given ($localname)
    {
    when (!/key/ and $self->in_a_dict)
        {
            # Then we must have just finished reading a value, and have exited a key/val pair. This should work for dict values too, when we finally exit them.
            @key_stack->shift; continue
        }
    when (/(dict|array)/) 
        { @data_structure_stack->shift; }
    }

}

sub characters {
    my ($self, $characters_structure) = @_;
    my $data = $characters_structure->{Data};
    
    
    if ($self->in_a_dict) # then it's a key or a value.
    {
        if ($element_stack[0] eq 'key')
        {  
            @key_stack->unshift($data);
            say $data if $data eq 'Tracks';
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
