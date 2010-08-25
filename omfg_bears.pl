#!/usr/bin/env perl


use perl5i::2;
use Modern::Perl;
use XML::SAX;


package TestBearAttributes;

use Moose;

has 'BearVar' => ( is => 'bare', default => 1, init_arg => undef );
has 'BugVar' => ( is => 'rw', default => "1", init_arg => undef );
has 'BearArray' => ( 
	is => 'ro', 
	default => sub{ [] }, 
	init_arg => undef, 
	isa => 'ArrayRef'
# 	traits => ['Array'],
# 	handles => {
# 		'push', 'pop'
# 	}
); 

sub return_bear {
	my ($self) = @_;
	return $self->{'BearVar'};
}

sub return_and_increment_bear {
	my ($self) = @_;
	return $self->{'BearVar'}++;
}

sub mutate_bugs {
	my ($self) = @_;
	$self->BugVar("All bugs re-mutated. One.");
}



package main;

my $spottedbear = TestBearAttributes->new();
# print $spottedbear->return_and_increment_bear;
# print $spottedbear->return_and_increment_bear;
# print $spottedbear->return_and_increment_bear;
# print $spottedbear->return_and_increment_bear;
# print $spottedbear->return_and_increment_bear;

# $spottedbear->BearArray->push(30);
# $spottedbear->BearArray->push(90); 
# print @{$spottedbear->BearArray()};
# print $spottedbear->BearArray->[1];

$spottedbear->BugVar("I am now a bug.");
print $spottedbear->BugVar;
$spottedbear->mutate_bugs;
print $spottedbear->BugVar;
