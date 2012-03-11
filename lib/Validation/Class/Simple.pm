# ABSTRACT: Simple Inline Validation Class

package Validation::Class::Simple;
{
    $Validation::Class::Simple::VERSION = '5.61';
}

use Validation::Class;

our $VERSION = '5.61';    # VERSION


1;
__END__

=pod

=head1 NAME

Validation::Class::Simple - Simple Inline Validation Class

=head1 VERSION

version 5.61

=head1 DESCRIPTION

Validation::Class::Simple is simply a throw-away namespace, good for defining
a validation class on-the-fly (in scripts, etc) in situations where a full-fledged
validation class is not warranted, e.g. (scripts, etc).

Simply define your data validation profile and execute, much in the same way
you would use most other data validation libraries available.

Should you find yourself wanting to switch to a full-fledged validation class
using L<Validation::Class>, you could do so very easily as the validation field
specification is exactly the same.

=head2 SYNOPSIS

    use Validation::Class::Simple;
    
    my $fields = {
        'login'  => {
            label      => 'User Login',
            error      => 'Login invalid.',
            required   => 1,
            validation => sub {
                my ($self, $this_field, $all_params) = @_;
                return $this_field->{value} eq 'admin' ? 1 : 0;
            }
        },
        'password'  => {
            label         => 'User Password',
            error         => 'Password invalid.',
            required      => 1,
            validation    => sub {
                my ($self, $this_field, $all_params) = @_;
                return $this_field->{value} eq 'pass' ? 1 : 0;
            }
        }    
    };
    
    # my $params  = { ... }
    
    my $input = Validation::Class::Simple->new(    
        fields => $fields, params => $params
    );
    
    unless ($input->validate) {
    
        return $input->errors_to_string;
    
    }

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

