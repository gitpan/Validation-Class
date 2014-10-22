# ABSTRACT: Length Directive for Validation Class Field Definitions

package Validation::Class::Directive::Length;

use strict;
use warnings;

use base 'Validation::Class::Directive';

use Validation::Class::Util;

our $VERSION = '7.900023'; # VERSION


has 'mixin'   => 1;
has 'field'   => 1;
has 'multi'   => 0;
has 'message' => '%s should be exactly %s characters';

sub validate {

    my $self = shift;

    my ($proto, $field, $param) = @_;

    if (defined $field->{length} && defined $param) {

        my $length = $field->{length};

        if ($field->{required} || $param) {

            unless (length($param) == $length) {

                $self->error(@_, $length);

            }

        }

    }

    return $self;

}

1;

__END__
=pod

=head1 NAME

Validation::Class::Directive::Length - Length Directive for Validation Class Field Definitions

=head1 VERSION

version 7.900023

=head1 SYNOPSIS

    use Validation::Class::Simple;

    my $rules = Validation::Class::Simple->new(
        fields => {
            security_pin => {
                length => 4
            }
        }
    );

    # set parameters to be validated
    $rules->params->add($parameters);

    # validate
    unless ($rules->validate) {
        # handle the failures
    }

=head1 DESCRIPTION

Validation::Class::Directive::Length is a core validation class field directive
that validates the exact length of the associated parameters.

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

