#!/usr/bin/env perl





use perl5i::2;
use Modern::Perl;
use XML::SAX;
use SaxTrackHandlerStub; # HURF DURF, not needed. except now it is!
use Data::Dumper;


my %ArtistAlbums;
my %Compilations;

# my $parser = XML::SAX::ParserFactory->parser( Handler => SaxTrackHandlerStub->new(ArtistAlbumsShelf => \%ArtistAlbums, CompilationsShelf => \%Compilations));

my $handler = SaxTrackHandlerStub->new(ArtistAlbumsShelf => \%ArtistAlbums, CompilationsShelf => \%Compilations);


my $metainstance = $handler->meta();
my $metaclass = SaxTrackHandlerStub->meta();
# say $metainstance->class_precedence_list;
# say $handler->isa('XML::SAX::Base');
print Dumper \@SaxTrackHandlerStub::ISA;

