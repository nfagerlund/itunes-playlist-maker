#!/usr/bin/env perl



package SaxTrackHandlerStub;

use Modern::Perl;
use Moose;
use MooseX::NonMoose;
# 	use MooseX::InsideOut;
# 	use XML::SAX::Base; #I  think I cane leave that off if I'm using NonMoose? 
# BEGIN {extends 'XML::SAX::Base';}
extends 'XML::SAX::Base';
# 	extends qw( Moose::Object XML::SAX::Base ); 

# 	use perl5i::2; Uh, not for now? Let's try that again. 
# 	use XML::Filter::BufferText;
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



1;
