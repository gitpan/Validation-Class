# ABSTRACT: Generic Container Class for Various Collections

package Validation::Class::Collection;
{
    $Validation::Class::Collection::VERSION = '7.25';
}

use strict;
use warnings;

our $VERSION = '7.25';    # VERSION

use Carp 'confess';


sub new {

    my $class = shift;

    my %arguments = @_ % 2 ? %{$_[0]} : @_;

    my $self = bless {}, $class;

    while (my ($name, $value) = each(%arguments)) {

        $self->add($name => $value);

    }

    return $self;

}


sub add {

    my $self = shift;

    my %arguments = @_ % 2 ? %{$_[0]} : @_;

    while (my ($key, $object) = each %arguments) {

        $self->{$key} = $object;

    }

    return $self;

}


sub clear {

    my ($self) = @_;

    delete $self->{$_} for keys %{$self};

    return $self;

}


sub count {

    return scalar(keys %{$_[0]});

}


sub each {

    my ($self, $transformer) = @_;

    $transformer ||= sub {@_};

    my %hash = %{$self};

    while (my @kv = each(%hash)) {

        $transformer->(@kv);

    }

    return $self;

}


sub find {

    my ($self, $pattern) = @_;

    return undef unless "REGEXP" eq uc ref $pattern;

    my %matches = ();

    $matches{$_} = $self->{$_} for grep { $_ =~ $pattern } keys %{$self};

    return {%matches};

}


sub has {

    my ($self, $name) = @_;

    return defined $self->{$name} ? 1 : 0;

}


sub hash {

    return {%{$_[0]}};

}


sub keys {

    return (keys %{$_[0]});

}


sub list {

    return (values %{$_[0]});

}


sub remove {

    my ($self, $name) = @_;

    return delete $self->{$name} if $name;

}


sub values {

    goto &list;

}

1;
__END__

=pod

=head1 NAME

Validation::Class::Collection - Generic Container Class for Various Collections

=head1 VERSION

version 7.25

=head1 SYNOPSIS

    use Validation::Class::Collection;
    
    my $foos = Validation::Class::Collection->new;
    
    $foos->add(foo => Foo->new);
    
    print $foos->count; # 1 object

=head1 DESCRIPTION

Validation::Class::Collection provides an all-purpose container for objects.
This class is primarily used as a base class for collection management classes.

=head1 METHODS

=head2 new

    my $self = Validation::Class::Collection->new;

=head2 add

    $self = $self->add(foo => Foo->new);
    
    $self->add(foo => Foo->new, bar => Bar->new);

=head2 clear

    $self = $self->clear;

=head2 count

    my $count = $self->count; 

=head2 each

    $self = $self->each(sub{
        
        my ($name, $object) = @_;
        ...
        
    });

=head2 find

    my $matches = $self->find(qr/update_/); # hashref

=head2 has

    if ($self->has($name)) {
        ...
    }

=head2 hash

    my $hash = $self->hash; 

=head2 keys

    my @keys = $self->keys;

=head2 list

    my @objects = $self->list;

=head2 remove

    $object = $self->remove($name);

=head2 values

    my @objects = $self->values;

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

