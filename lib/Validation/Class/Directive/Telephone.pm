# ABSTRACT: Telephone Directive for Validation Class Field Definitions

package Validation::Class::Directive::Telephone;

use strict;
use warnings;

use base 'Validation::Class::Directive';

use Validation::Class::Util;

our $VERSION = '7.900030'; # VERSION


has 'mixin'   => 1;
has 'field'   => 1;
has 'multi'   => 0;
has 'message' => '%s is not a valid telephone number';

sub validate {

    my ($self, $proto, $field, $param) = @_;

    if (defined $field->{telephone} && defined $param) {

        if ($field->{required} || $param) {

            my $tre = qr/^(?:\+?1)?[-. ]?\(?[2-9][0-8][0-9]\)?[-. ]?[2-9][0-9]{2}[-. ]?[0-9]{4}$/;

            $self->error($proto, $field) unless $param =~ $tre;

        }

    }

    return $self;

}

1;

__END__
=pod

=head1 NAME

Validation::Class::Directive::Telephone - Telephone Directive for Validation Class Field Definitions

=head1 VERSION

version 7.900030

=head1 SYNOPSIS

    use Validation::Class::Simple;

    my $rules = Validation::Class::Simple->new(
        fields => {
            user_phone => {
                telephone => 1
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

Validation::Class::Directive::Telephone is a core validation class field
directive that handles telephone number validation for the USA and North America.

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

