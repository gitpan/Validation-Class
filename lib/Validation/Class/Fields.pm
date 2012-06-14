# ABSTRACT: Container Class for Validation::Class::Field Objects

package Validation::Class::Fields;
{
    $Validation::Class::Fields::VERSION = '7.50';
}

use strict;
use warnings;

our $VERSION = '7.50';    # VERSION

use Carp 'confess';

use base 'Validation::Class::Collection';

use Validation::Class::Field;


sub add {

    my $self = shift;

    my %arguments = @_ % 2 ? %{$_[0]} : @_;

    while (my ($key, $object) = each %arguments) {

        $object->{name} = $key
          unless defined $object->{name};

        $object = Validation::Class::Field->new($object)
          unless "Validation::Class::Field" eq ref $object;

        $self->{$key} = $object;

    }

    return $self;

}

sub clear {

    #noop - fields can't be deleted this way

}

1;
__END__

=pod

=head1 NAME

Validation::Class::Fields - Container Class for Validation::Class::Field Objects

=head1 VERSION

version 7.50

=head1 SYNOPSIS

    ...

=head1 DESCRIPTION

Validation::Class::Fields is a container class for L<Validation::Class::Field>
objects and is derived from the L<Validation::Class::Collection> class.

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

