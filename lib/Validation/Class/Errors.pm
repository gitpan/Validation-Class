# Input Validation Error Handling

use strict;
use warnings;

package Validation::Class::Errors;
{
    $Validation::Class::Errors::VERSION = '2.7.6';
}

our $VERSION = '2.7.6';    # VERSION

use Moose::Role;

sub error_count {
    return scalar(@{shift->{errors}});
}

sub errors_to_string {
    return join(($_[1] || ', '), @{$_[0]->{errors}});
}

no Moose::Role;

1;
