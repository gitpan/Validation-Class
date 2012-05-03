# ABSTRACT: Container Class for Data Input Parameters

package Validation::Class::Params;
{
    $Validation::Class::Params::VERSION = '7.15';
}

use strict;
use warnings;

our $VERSION = '7.15';    # VERSION

use Carp 'confess';

use base 'Validation::Class::Collection';


1;
__END__

=pod

=head1 NAME

Validation::Class::Params - Container Class for Data Input Parameters

=head1 VERSION

version 7.15

=head1 SYNOPSIS

    ...

=head1 DESCRIPTION

Validation::Class::Params is a container class for standard data input
parameters and is derived from the L<Validation::Class::Collection> class.

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

