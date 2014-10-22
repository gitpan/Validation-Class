# ABSTRACT: Name Directive for Validation Class Field Definitions

package Validation::Class::Directive::Name;

use strict;
use warnings;

use base 'Validation::Class::Directive';

use Validation::Class::Util;

our $VERSION = '7.900016'; # VERSION


has 'mixin' => 1;
has 'field' => 1;
has 'multi' => 0;

1;

__END__
=pod

=head1 NAME

Validation::Class::Directive::Name - Name Directive for Validation Class Field Definitions

=head1 VERSION

version 7.900016

=head1 DESCRIPTION

Validation::Class::Directive::Name is a core validation class field directive
that merely holds the name of the associated field. This directive is used
internally and the value is populated automatically.

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

