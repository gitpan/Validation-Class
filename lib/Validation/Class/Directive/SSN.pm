# ABSTRACT: SSN Directive for Validation Class Field Definitions

package Validation::Class::Directive::SSN;

use strict;
use warnings;

use base 'Validation::Class::Directive';

use Validation::Class::Util;

our $VERSION = '7.900013'; # VERSION


has 'mixin'   => 1;
has 'field'   => 1;
has 'multi'   => 0;
has 'message' => '%s is not a valid social security number';

sub validate {

    my ($self, $proto, $field, $param) = @_;

    if (defined $field->{ssn} && defined $param) {

        if ($field->{required} || $param) {

            my $ssnre = qr/\A\b(?!000)[0-9]{3}-[0-9]{2}-[0-9]{4}\b\z/i;
            $self->error($proto, $field) unless $param =~ $ssnre;

        }

    }

    return $self;

}

1;

__END__
=pod

=head1 NAME

Validation::Class::Directive::SSN - SSN Directive for Validation Class Field Definitions

=head1 VERSION

version 7.900013

=head1 SYNOPSIS

    use Validation::Class::Simple;

    my $rules = Validation::Class::Simple->new(
        fields => {
            user_ssn => {
                ssn => 1
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

Validation::Class::Directive::SSN is a core validation class field directive
that handles validation of social security numbers in the USA.

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

