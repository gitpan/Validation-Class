# ABSTRACT: Container Class for Relatives

package Validation::Class::Relatives;
{
    $Validation::Class::Relatives::VERSION = '7.82';
}

use strict;
use warnings;

our $VERSION = '7.82';    # VERSION

use Carp 'confess';

use base 'Validation::Class::Collection';


1;
__END__

=pod

=head1 NAME

Validation::Class::Relatives - Container Class for Relatives

=head1 VERSION

version 7.82

=head1 SYNOPSIS

    ...

=head1 DESCRIPTION

Validation::Class::Relatives is a container class for sub-classes registered via
the set/load function, this class is derived from the
L<Validation::Class::Collection> class.

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

