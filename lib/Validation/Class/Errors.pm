# ABSTRACT: Error Handling Object for Fields and Classes

package Validation::Class::Errors;
{
  $Validation::Class::Errors::VERSION = '7.00_01';
}

use strict;
use warnings;

our $VERSION = '7.00_01'; # VERSION

use Carp 'confess';
use Validation::Class::Base 'has';



sub new {
    
    my $class = shift;
    
    my @arguments = @_ ? @_ > 1 ? @_ : "ARRAY" eq ref $_[0] ? @{$_[0]} : () : ();
    
    my $self = bless [], $class;
    
    $self->add_error($_) for @arguments;
    
    return $self;
    
}


sub add_error { goto &add_errors }


sub add_errors {
    
    my ($self, @error_messages) = @_;
    
    return undef unless @error_messages;
    
    my %seen = map { $_ => 1 } @{$self};
    
    push @{$self}, grep { !$seen{$_} } @error_messages;
    
    return $self;
    
}


sub all_errors {
    
    return (@{$_[0]});
    
}


sub clear_errors {
    
    my ($self) = @_;
    
    delete $self->[$_] for (0..($self->count_errors - 1)) ;
    
    return $self;
    
}


sub count_errors {
    
    return scalar(@{$_[0]});
    
}


sub each_error {
    
    my ($self, $transformer) = @_;
    
    $transformer ||= sub {@_} ;
    
    return [ map {
        
        $_ = $transformer->($_)
        
    } @{$self} ]
    
}


sub error_list {
    
    return [@{$_[0]}];
    
}


sub find_errors {
    
    my ($self, $pattern) = @_;
    
    return undef unless "REGEXP" eq uc ref $pattern;
    
    return ( grep { $_ =~ $pattern } $self->all_errors );
    
}


sub first_error {
    
    my ($self, $pattern) = @_;
    
    return $self->error_list->[0] unless "REGEXP" eq uc ref $pattern;
    
    return ( $self->find_errors($pattern) )[ 0 ];
    
}


sub get_error {
    
    my ($self) = @_;
    
    return $self->first_error;
    
}


sub get_errors {
    
    my ($self) = @_;
    
    return $self->all_errors;
    
}


sub has_errors {
    
    my ($self) = @_;
    
    return $self->count_errors ? 1 : 0;
    
}


sub join_errors {
    
    my ($self, $delimiter) = @_;
    
    $delimiter = ', ' unless defined $delimiter;
    
    return join $delimiter, $self->all_errors;
    
}


sub to_string {
    
    my ($self, $delimiter, $transformer) = @_;
    
    $delimiter = ', ' unless defined $delimiter; # default delimiter is a comma-space
    
    $self->each_error($transformer) if $transformer;
    
    return $self->join_errors($delimiter);

}

1;
__END__
=pod

=head1 NAME

Validation::Class::Errors - Error Handling Object for Fields and Classes

=head1 VERSION

version 7.00_01

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

=head2 add_error

    $self = $self->add_error("houston, we have a problem", "this isn't cool");

=head2 add_errors

    $self = $self->add_errors("houston, we have a problem", "this isn't cool");

=head2 all_errors

    my @list = $self->all_errors;

=head2 clear_errors

    $self = $self->clear_errors; 

=head2 count_errors

    my $count = $self->count_errors; 

=head2 each_error

    my $list = $self->each_error(sub{ ucfirst lc shift });

=head2 error_list

    my $list = $self->error_list;

=head2 find_errors

    my @matches = $self->find_errors(qr/password/);

=head2 first_error

    my $item = $self->first_error;
    my $item = $self->first_error(qr/password/);

=head2 get_error

    my $item = $self->get_error; # first error

=head2 get_errors

    my @list = $self->get_errors; # all errors

=head2 has_errors

    my $true = $self->has_errors; 

=head2 join_errors

    my $string = $self->join_errors; # returns "an error, another error"
    
    my $string = $self->join_errors($delimiter); 

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

