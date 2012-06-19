# ABSTRACT: Error Handling Object for Fields and Classes

package Validation::Class::Errors;
{
    $Validation::Class::Errors::VERSION = '7.66';
}

use strict;
use warnings;

our $VERSION = '7.66';    # VERSION


sub new {

    my $class = shift;

    my @arguments =
      @_ ? @_ > 1 ? @_ : "ARRAY" eq ref $_[0] ? @{$_[0]} : () : ();

    my $self = bless [], $class;

    $self->add($_) for @arguments;

    return $self;

}


sub add {

    my ($self, @error_messages) = @_;

    return undef unless @error_messages;

    my %seen = map { $_ => 1 } @{$self};

    push @{$self}, grep { !$seen{$_} } @error_messages;

    return $self;

}


sub all {

    return (@{$_[0]});

}


sub clear {

    my ($self) = @_;

    delete $self->[($_ - 1)] for (1 .. $self->count);

    return $self;

}


sub count {

    return scalar(@{$_[0]});

}


sub each {

    my ($self, $transformer) = @_;

    $transformer ||= sub {@_};

    return [
        map {

            $_ = $transformer->($_)

          } @{$self}
      ]

}


sub list {

    return [@{$_[0]}];

}


sub find {

    my ($self, $pattern) = @_;

    return undef unless "REGEXP" eq uc ref $pattern;

    return (grep { $_ =~ $pattern } $self->all);

}


sub first {

    my ($self, $pattern) = @_;

    return $self->list->[0] unless "REGEXP" eq uc ref $pattern;

    return ($self->find($pattern))[0];

}


sub join {

    my ($self, $delimiter) = @_;

    $delimiter = ', ' unless defined $delimiter;

    return join $delimiter, $self->all;

}


sub to_string {

    my ($self, $delimiter, $transformer) = @_;

    $delimiter = ', '
      unless defined $delimiter;    # default delimiter is a comma-space

    $self->each($transformer) if $transformer;

    return $self->join($delimiter);

}

1;
__END__

=pod

=head1 NAME

Validation::Class::Errors - Error Handling Object for Fields and Classes

=head1 VERSION

version 7.66

=head1 SYNOPSIS

    package SomeClass;
    
    use Validation::Class;
    
    package main;
    
    my $class = SomeClass->new;
    
    ...
    
    # errors at the class-level
    my $errors = $class->errors ;
    
    print $errors->to_string;
    
    # errors at the field-level
    my $field_errors = $user->fields->{name}->{errors} ;
    
    print $field_errors->to_string;
    
    1;

=head1 DESCRIPTION

Validation::Class::Errors is responsible for error handling in Validation::Class
derived classes on both the class and field levels respectively.

=head1 METHODS

=head2 new

    my $self = Validation::Class::Errors->new;

=head2 add

    $self = $self->add("houston, we have a problem", "this isn't cool");

=head2 all

    my @list = $self->all;

=head2 clear

    $self = $self->clear; 

=head2 count

    my $count = $self->count; 

=head2 each

    my $list = $self->each(sub{ ucfirst lc shift });

=head2 list

    my $list = $self->list;

=head2 find

    my @matches = $self->find(qr/password/);

=head2 first

    my $item = $self->first;
    my $item = $self->first(qr/password/);

=head2 join

    my $string = $self->join; # returns "an error, another error"
    
    my $string = $self->join($delimiter); 

=head2 to_string

The to_string method stringifies the errors using the specified delimiter or ", "
(comma-space) by default. 

    my $string =  $self->to_string; # returns "an error, another error"
    
    my $string = $self->to_string($delimiter, sub { ucfirst lc shift });

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

