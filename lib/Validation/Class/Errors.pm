# Input Validation Error Handling

use strict;
use warnings;

package Validation::Class::Errors;
{
  $Validation::Class::Errors::VERSION = '2.3.4';
}

our $VERSION = '2.3.4'; # VERSION

use Moose::Role;

sub error_count {
    return scalar(@{shift->{errors}});
}

sub errors_to_string {
    return join(($_[1]||', '), @{$_[0]->{errors}});
}

no Moose::Role;

1;