# ABSTRACT: Field Object for Validation::Class Classes

package Validation::Class::Field;
{
  $Validation::Class::Field::VERSION = '7.03';
}

use strict;
use warnings;

our $VERSION = '7.03'; # VERSION

use Carp 'confess';
use Validation::Class::Base 'has';
use Validation::Class::Prototype;

my $directives = Validation::Class::Prototype->configuration->{DIRECTIVES};

while (my($dir, $cfg) = each %{$directives}) {
    
    if ($cfg->{field}) {
        
        next if $dir =~ s/[^a-zA-Z0-9\_]/\_/g;
        
        # create accessors from default configuration (once)
        has $dir => undef unless grep { $dir eq $_ } qw(errors); 
        
    }
    
}



has 'errors' => sub { Validation::Class::Errors->new };


sub new {
    
    my ($class, $config) = @_;
    
    confess "Can't create a new field object without a name attribute"
        unless $config->{name};
    
    my $self = bless $config, $class;
    
    delete $self->{errors} if exists $self->{errors};
    
    $self->errors; # initialize if not already
    
    return $self;
    
}

1;
__END__
=pod

=head1 NAME

Validation::Class::Field - Field Object for Validation::Class Classes

=head1 VERSION

version 7.03

=head1 SYNOPSIS

    package SomeClass;
    
    use Validation::Class;
    
    package main;
    
    my $class = SomeClass->new;
    
    ...
    
    my $field = $class->get_field('some_field_name');
    
    $field->apply_filters;
    
    $field->validate; # validate this only
    
    $field->errors->count; # field-level errors
    
    1;

=head1 DESCRIPTION

Validation::Class::Field is responsible for field data handling in
Validation::Class derived classes, performs functions at the field-level only.

This class automatically creates attributes for all acceptable field directives
as listed under L<Validation::Class::Prototype/DIRECTIVES>.

=head1 ATTRIBUTES

=head2 errors

The errors attribute is a L<Validation::Class::Errors> object.

=head1 METHODS

=head2 new

    my $self = Validation::Class::Field->new({
        name => 'some_field_name'
    });

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

