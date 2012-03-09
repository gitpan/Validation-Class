# ABSTRACT: Marries Validation::Class and Moose through Traits

package Validation::Class::Moose;
{
    $Validation::Class::Moose::VERSION = '5.50';
}

use Moose::Role;
use Validation::Class::Simple;

our $VERSION = '5.50';    # VERSION


sub rules {

    my $self = shift;
    my $data = {fields => {}, params => {}};

    foreach my $attribute ($self->meta->get_all_attributes) {

        $data->{params}->{$attribute->name} = $attribute->get_value($self);
        $data->{fields}->{$attribute->name} = $attribute->rules;
        $data->{fields}->{$attribute->name}->{required} = 1
          if $attribute->{required};    # required attr condition

    }

    Validation::Class::Simple->new(%{$data});

}

# register virtual trait - escape the pause

{

    # Validation::Class Virtual Moose Trait
    package    # Don't register with PAUSE (pause.perl.org)
      Validation::Class::Moose::Trait::Rules;
    use Moose::Role;
    has rules => (
        is      => 'rw',
        isa     => 'HashRef',
        default => sub { {} }
    );

    # Validation::Class Virtual Trait
    package    # Don't register with PAUSE (pause.perl.org)
      Moose::Meta::Attribute::Custom::Trait::Rules;

    sub register_implementation {
        my $pkg = 'Validation_Class_Moose_Trait_Rules';
        $pkg =~ s/_/::/g;
        $pkg;
    }

}

1;
__END__

=pod

=head1 NAME

Validation::Class::Moose - Marries Validation::Class and Moose through Traits

=head1 VERSION

version 5.50

=head1 DESCRIPTION

Validation::Class::Moose is a L<Moose> role that infuses the power and
flexibility of L<Validation::Class> into your Moose classes. Validation::Class::Moose,
by design, is not designed for attribute type checking, the Moose type constraint
system exists for that purpose and works well, ... instead, its purpose is suited
for validating attribute values (parameters).

This class is experimental and hasn't been used in production. While it has been
tested, please note, the API may change.

=head2 SYNOPSIS

    package Identify;
    
    use  Moose;
    with 'Validation::Class::Moose';
    
    has login => (
        is     => 'rw',
        isa    => 'Str',
        traits => ['Rules'],
        rules  => {
            label      => 'User Login',
            error      => 'Login invalid.',
            required   => 1,
            validation => sub {
                my ( $self, $this_field, $all_params ) = @_;
                return $this_field->{value} eq 'admin' ? 1 : 0;
            }
        }
    );
    
    has password => (
        is     => 'rw',
        isa    => 'Str',
        traits => ['Rules'],
        rules  => {
            label      => 'User Password',
            error      => 'Password invalid.',
            required   => 1,
            validation => sub {
                my ( $self, $this_field, $all_params ) = @_;
                return $this_field->{value} eq 'pass' ? 1 : 0;
            }
        }
    );
    
    package main;
    
    my $id    = Identify->new(login => 'admin', password => 'xxxx');
    my $rules = $id->rules;
    
    unless ( $rules->validate ) {
        exit print $rules->errors_to_string;
    }

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

