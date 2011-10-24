# ABSTRACT: Input Validation Error Handling

use strict;
use warnings;

package Validation::Class::Errors;
{
  $Validation::Class::Errors::VERSION = '2.0.01';
}

our $VERSION = '2.0.01'; # VERSION

use Moose::Role;

sub error_count {
    return scalar(@{shift->{errors}});
}

sub errors_to_string {
    return join(($_[1]||', '), @{$_[0]->{errors}});
}

no Moose::Role;

1;
__END__
=pod

=head1 NAME

Validation::Class::Errors - Input Validation Error Handling

=head1 VERSION

version 2.0.01

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

