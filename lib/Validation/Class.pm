# ABSTRACT: Centralized Input Validation for Any Application

use strict;
use warnings;

package Validation::Class;
{
  $Validation::Class::VERSION = '1.9.5';
}

use 5.008001;

our $VERSION = '1.9.5'; # VERSION






















































use Validation::Class::Sugar ();
use Moose::Exporter;

my ($import, $unimport, $init_meta) = Moose::Exporter->build_import_methods(
    also             => 'Validation::Class::Sugar',
    base_class_roles => [
        'Validation::Class::Validator',
        'Validation::Class::Errors'
    ],
);

sub import {
    return unless $import;
    goto &$import;
}


sub unimport {
    return unless $unimport;
    goto &$unimport;
}

sub init_meta {
    my ($dummy, %opts) = @_;
    Moose->init_meta(%opts);
    Moose::Util::MetaRole::apply_base_class_roles(
        for   => $opts{for_class},
        roles => ['Validation::Class::Validator', 'Validation::Class::Errors']
    );
    return Class::MOP::class_of($opts{for_class});
}

1;
__END__
=pod

=head1 NAME

Validation::Class - Centralized Input Validation for Any Application

=head1 VERSION

version 1.9.5

=head1 SYNOPSIS

    use MyApp::Validation;
    
    my $input = MyApp::Validation->new(params => $params);
    
    unless ($input->validate()){
        return $input->errors_to_string;
    }

=head1 DESCRIPTION

Validation::Class is a different approach to data validation, it attempts to
simplify and centralize data validation rules to ensure DRY (don't repeat
yourself) code. The primary intent of this module is to provide a simplistic
validation framework. Your validation class is your data input firewall and
can be used anywhere and is flexible enough in an MVC environment to be used
in both the Controller and Model. A validation class is defined as follows:

    package MyApp::Validation;
    
    use Validation::Class;
    
    # a validation rule
    field 'login'  => {
        label      => 'User Login',
        error      => 'Login invalid.',
        required   => 1,
        validation => sub {
            my ($self, $this_field, $all_fields) = @_;
            return $this_field->{value} eq 'admin' ? 1 : 0;
        }
    };
    
    # a validation rule
    field 'password'  => {
        label         => 'User Password',
        error         => 'Password invalid.',
        required      => 1,
        validation    => sub {
            my ($self, $this_field, $all_fields) = @_;
            return $this_field->{value} eq 'pass' ? 1 : 0;
        }
    };
    
    1;

The fields defined will be used to validate the specified input parameters.
You specify the input parameters at instantiaton, parameters should take the
form of a hashref of key/value pairs. Multi-level (nested) hashrefs are allowed
and are inflated/deflated in accordance with the rules of L<Hash::Flatten> or
your hash inflator configuration. The following is an example on using your
validate class to validate input in various scenarios:

    # web app
    package MyApp;
    
    use MyApp::Validation;
    use Misc::WebAppFramework;
    
    get '/auth' => sub {
        # get user input parameters
        my $params = shift;
    
        # initialize validation class and set input parameters
        my $rules = MyApp::Validation->new(params => $params);
        
        unless ($rules->validate('login', 'password')) {
            
            # print errors to browser unless validation is successful
            return $rules->errors_to_string;
        }
        
        return 'you have authenticated';
    };

=head1 CHANGE NOTICE

B<Important Note!> Validation::Class is subject to change, you've been warned.
You should be fine if you stay tuned.

Validation::Class has been re-written using L<Moose>. Sorry
if you feel this bloats your application but using Moose was the better approach.

Validation::Class now supports hash serialization/deserialization which means
that you can now set the parameters using a hashref of nested hashrefs and
validate against them, or set the parameters using a hashref of key/value pairs
and validate against that. This function is provided in Validation::Class via
L<Hash::Flatten>. The following is an example of that:

    my $params = {
        user => {
            login => 'admin',
            password => 'pass'
        }
    };
    
    my $rules = MyApp::Validation->new(params => $params);
    
    # or
    
    my $params = {
        'user.login' => 'admin',
        'user.password' => 'pass'
    };
    
    my $rules = MyApp::Validation->new(params => $params);
    
    # after filtering, validation, etc ... return your params as a hashref if
    # needed
    
    my $params = $rules->get_params_hash;

=head1 BUILDING A VALIDATION CLASS

    package MyApp::Validation;
    
    use Validation::Class;
    
    # a validation rule template
    mixin 'basic'  => {
        required   => 1,
        min_length => 1,
        max_length => 255,
        filters    => ['lowercase', 'alphanumeric']
    };
    
    # a validation rule
    field 'user.login'  => {
        mixin      => 'basic',
        label      => 'user login',
        error      => 'login invalid',
        validation => sub {
            my ($self, $this, $fields) = @_;
            return $this->{value} eq 'admin' ? 1 : 0;
        }
    };
    
    # a validation rule
    field 'user.password'  => {
        mixin         => 'basic',
        label         => 'user login',
        error         => 'login invalid',
        validation    => sub {
            my ($self, $this, $fields) = @_;
            return $this->{value} eq 'pass' ? 1 : 0;
        }
    };
    
    1;

=head2 THE MIXIN KEYWORD

The mixin keyword creates a validation rules template that can be applied to any
field using the mixin directive.

    package MyApp::Validation;
    use Validation::Class;
    
    mixin 'constrain' => {
        required   => 1,
        min_length => 1,
        max_length => 255,
        ...
    };
    
    # e.g.
    field 'login' => {
        mixin => 'constrain',
        ...
    };

=head2 THE FILTER KEYWORD

The filter keyword creates custom filters to be used in your field definitions.

    package MyApp::Validation;
    use Validation::Class;
    
    filter 'usa_telephone_number_converter' => sub {
        $_[0] =~ s/\D//g;
        my ($ac, $pre, $num) = $_[0] =~ /(\d{3})(\d{3})(\d{4})/;
        $_[0] = "($ac) $pre-$num";
    };
    
    # e.g.
    field 'my_telephone' => {
        filter => ['trim', 'usa_telephone_number_converter'],
        ...
    };

=head2 THE DIRECTIVE KEYWORD

The directive keyword creates custom validator directives to be used in your field
definitions. The routine is passed two parameters, the value of directive and the
value of the field the validator is being processed against. The validator should
return true or false.

    package MyApp::Validation;
    use Validation::Class;
    
    directive 'between' => sub {
        my ($directive, $value, $field, $class) = @_;
        my ($min, $max) = split /\-/, $directive;
        unless ($value > $min && $value < $max) {
            my $handle = $field->{label} || $field->{name};
            $class->error($field, "$handle must be between $directive");
            return 0;
        }
        return 1;
    };
    
    # e.g.
    field 'hours' => {
        between => '00-24',
        ...
    };

=head2 THE FIELD KEYWORD

The field keyword creates a validation block and defines validation rules for
reuse in code. The field keyword should correspond with the parameter name
expected to be passed to your validation class.

    package MyApp::Validation;
    use Validation::Class;
    
    field 'login' => {
        required   => 1,
        min_length => 1,
        max_length => 255,
        ...
    };

The field keword takes two arguments, the field name and a hashref of key/values
pairs.

=head1 DEFAULT FIELD/MIXIN DIRECTIVES

    package MyApp::Validation;
    use Validation::Class;
    
    # a validation template
    mixin '...'  => {
        # mixin directives here
        ...
    };
    
    # a validation rule
    field '...'  => {
        # field directives here
        ...
    };
    
    1;

When building a validation class, the first encountered and arguably two most
important keyword functions are field() and mixin() which are used to declare
their respective properties. A mixin() declares a validation template where
its properties are intended to be copied within field() declarations which
declares validation rules, filters and other properties.

Both the field() and mixin() declarations/functions require two parameters, the
first being a name, used to identify the declaration and to be matched against
incoming input parameters, and the second being a hashref of key/value pairs.
The key(s) within a declaration are commonly referred to as directives.

The following is a list of default directives which can be used in field/mixin
declarations:

=head2 alias

The alias directive is useful when many different parameters with different
names can be validated using a single rule. E.g. The paging parameters in a
webapp may take on different names but require the same validation.

    # the alias directive
    field 'pager'  => {
        alias => ['page_user_list', 'page_other_list']
        ...
    };

=head2 error/errors

The error/errors directive is used to replace the system generated error
messages when a particular field doesn't validate. If a field fails multiple
directives, multiple errors will be generate for the same field. This may not
be desirable, the error directive overrides this behavior and only the specified
error is registered and displayed.

    # the error(s) directive
    field 'foobar'  => {
        errors => 'Foobar failed processing, Wtf?',
        ...
    };

=head2 label

The label directive is used as a user-friendly reference when the field name
is a serialized hash key or just plain ugly.

    # the label directive
    field 'hashref.foo.bar'  => {
        label => 'Foo Bar',
        ...
    };

=head2 mixin

The mixin directive is used to create a template of directives to be applied to
other fields.

    mixin 'ID' => {
        required => 1,
        min_length => 1,
        max_length => 11
    };

    # the mixin directive
    field 'user.id'  => {
        mixin => 'ID',
        ...
    };

=head2 mixin_field

The mixin directive is used to copy all directives from an existing field
except for the name, label, and validation directives.

    # the mixin_field directive
    field 'foobar'  => {
        label => 'Foo Bar',
        required => 1
    };
    
    field 'barbaz'  => {
        mixin_field => 'foobar',
        label => 'Bar Baz',
        ...
    };

=head2 name

The name directive is used *internally* and cannot be changed.

    # the name directive
    field 'thename'  => {
        ...
    };

=head2 required

The required directive is an important directive but can be misunderstood.
The required directive used to ensure the *submitted* parameter exists and has
a value. If the parameter is never submitted, the required directive has no
effect *unless* the field name is specified when validate() is called.

    # the required directive
    field 'foobar'  => {
        required => 1,
        ...
    };
    
    # pass
    my $rules = MyApp::Validation->new(params => { barbaz => 'blahblahblah' });
    $rules->validate('barbaz');
    
    # fail
    my $rules = MyApp::Validation->new(params => { barbaz => 'blahblahblah' });
    $rules->validate('foobar');
    
    # fail
    my $rules = MyApp::Validation->new(params => { barbaz => 'blahblahblah' });
    $rules->validate('foobar');
    
    # pass
    my $rules = MyApp::Validation->new(params => { foobar => 'blahblahblah' });
    $rules->validate('foobar');

=head2 validation

The validation directive is a coderef used add additional custom validation to
the field.

    # the validation directive
    field 'login'  => {
        validation => sub {
            my ($self, $this_field, $all_fields) = @_;
            return 0 unless $this_field->{value};
            return $this_field->{value} eq 'admin' ? 1 : 0;
        },
        ...
    };

=head2 value

The value directive is used as a kindof default value for a field to be used
when a matching parameter is not present.

    # the value directive
    field 'quantity'  => {
        value => 1,
        ...
    };

=head1 DEFAULT FIELD/MIXIN FILTER DIRECTIVES

=head2 filter/filters

The filter/filters directive is used to correct, altering and/or format the
values of the matching input parameter. Note: Filtering is applied before
validation. The filter directive can have multiple filters (even a coderef)
in the form of an arrayref of values.

    # the filter(s) directive
    field 'text'  => {
        filter => [qw/trim strip/ => sub {
            $_[0] =~ s/\D//g;
        }],
        ...
    };

The following is a list of default filters that may be used with the filter
directive:

=head3 alpha

The alpha filter removes all non-Alphabetic characters from the field's value.

    field 'foobar'  => {
        filter => 'alpha',
    };

=head3 alphanumeric

The alpha filter removes all non-Alphabetic and non-Numeric characters from the
field's value.

    field 'foobar'  => {
        filter => 'alphanumeric',
    };

=head3 capitalize

The capitalize filter attempts to capitalize the first word in each sentence,
where sentences are seperated by a period and space, within the field's value.

    field 'foobar'  => {
        filter => 'capitalize',
    };

=head3 decimal

The decimal filter removes all non-decimal-based characters from the field's
value. Allows-only: decimal, comma, and numbers.

    field 'foobar'  => {
        filter => 'decimal',
    };

=head3 numeric

The numeric filter removes all non-Numeric characters from the field's
value.

    field 'foobar'  => {
        filter => 'numeric',
    };

=head3 strip

As with the trim filter the strip filter removes leading and trailing
whitespaces from the field's value and additionally removes multiple whitespaces
from between the values characters.

    field 'foobar'  => {
        filter => 'strip',
    };

=head3 titlecase

The titlecase filter converts the field's value to titlecase by capitalizing the
first letter of each word.

    field 'foobar'  => {
        filter => 'titlecase',
    };

=head3 trim

The trim filter removes leading and trailing whitespaces from the field's value.

    field 'foobar'  => {
        filter => 'trim',
    };

=head3 uppercase

The uppercase filter converts the field's value to uppercase.

    field 'foobar'  => {
        filter => 'uppercase',
    };

=head1 DEFAULT FIELD/MIXIN VALIDATOR DIRECTIVES

    package MyApp::Validation;
    
    use Validation::Class;
    
    # a validation rule with validator directives
    field 'telephone_number'  => {
        length => 14,
        pattern => '(###) ###-####',
        ...
    };
    
    1;

Validator directives are special directives with associated validation code that
is used to validate common use-cases such as "checking the length of a parameter",
etc.

The following is a list of the default validators which can be used in field/mixin
declarations:

=head2 between

    # the between directive
    field 'foobar'  => {
        between => '1-5',
        ...
    };

=head2 length

    # the length directive
    field 'foobar'  => {
        length => 20,
        ...
    };

=head2 matches

    # the matches directive
    field 'this_field'  => {
        matches => 'another_field',
        ...
    };

=head2 max_length

    # the max_length directive
    field 'foobar'  => {
        max_length => '...',
        ...
    };

=head2 min_length

    # the min_length directive
    field 'foobar'  => {
        min_length => 5,
        ...
    };

=head2 options

    # the options directive
    field 'status'  => {
        options => 'Active, Inactive',
        ...
    };

=head2 pattern

    # the pattern directive
    field 'telephone'  => {
        pattern => '### ###-####',
        ...
    };
    
    field 'country_code'  => {
        pattern => 'XX',
        filter  => 'uppercase'
        ...
    };

=head1 THE VALIDATION CLASS

The following is an example of how to use your constructed validation class in
other code, .e.g. Web App Controller, etc.

    use MyApp::Validation;
    
    my $input = MyApp::Validation->new(params => $params);
    unless ($input->validate('field1','field2')){
        return $input->errors_to_string;
    }

Feeling lazy, have your validation class automatically find the appropriate fields
to validate against (params must match field names).

    use MyApp::Validation;
    
    my $input = MyApp::Validation->new(params => $params);
    unless ($input->validate){
        return $input->errors_to_string;
    }

You can define an alias to automatically map a parameter to a validation field
whereby a field definition will have an alias attribute containing an arrayref
of alternate parameters that can be matched against passed-in parameters.

    package MyApp::Validation;
    
    field 'foo.bar' => {
        ...,
        alias => [
            'foo',
            'bar',
            'baz',
            'bax'
        ]
    };

    use MyApp::Validation;
    
    my  $input = MyApp::Validation->new(params => { foo => 1 });
    unless ($input->validate(){
        return $input->errors_to_string;
    }

=head2 new

The new method instantiates and returns an instance of your validation class.

    use MyApp::Validation;
    
    my $input = MyApp::Validation->new;
    $input->params($params);
    ...
    
    my $input = MyApp::Validation->new(params => $params);
    ...

=head1 VALIDATION CLASS ATTRIBUTES

=head2 ignore_unknown

The ignore_unknown boolean determines whether your application will live or die
upon encountering unregistered field directives during validation.

    my $self = MyApp::Validation->new(params => $params, ignore_unknown => 1);
    $self->ignore_unknown(1);
    ...

=head2 fields

The fields attribute returns a hashref of defined fields, filtered and merged
with thier parameter counterparts.

    my $self = MyApp::Validation->new(fields => $fields);
    my $fields = $self->fields();
    ...

=head2 filters

The filters attribute returns a hashref of pre-defined filter definitions.

    my $filters = $self->filters();
    ...

=head2 hash_inflator

The hash_inflator value determines how the hash serializer (inflation/deflation)
behaves. The value must be a hashref of L<Hash::Flatten/OPTIONS> options. Purely
for the sake of consistency, you can use lowercase keys (with underscores) which
will be converted to camelcased keys before passed to the serializer.

    my $self = MyApp::Validation->new(
        hash_inflator => {
            hash_delimiter => '/',
            array_delimiter => '//'
        }
    );
    ...

=head2 mixins

The mixins attribute returns a hashref of defined validation templates.

    my $mixins = $self->mixins();
    ...

=head2 params

The params attribute gets/sets the parameters to be validated.

    my $input = {
        ...
    };
    
    my $self = MyApp::Validation->new(params => $input);
    
    $self->params($input);
    my $params = $self->params();
    
    ...

=head2 report_unknown

The report_unknown boolean determines whether your application will report
unregistered fields as class-level errors upon encountering unregistered field
directives during validation.

    my $self = MyApp::Validation->new(params => $params,
    ignore_unknown => 1, report_unknown => 1);
    $self->report_unknown(1);
    ...

=head2 reset_fields

The reset_fields effectively resets any altered field objects at the class level.
This method is called automatically everytime the new() method is triggered.

    $self->reset_fields();

=head1 VALIDATION CLASS METHODS

=head2 error

The error function is used to set and/or retrieve errors encountered during
validation. The error function with no parameters returns the error message object
which is an arrayref of error messages stored at class-level. 

    # return all errors encountered/set as an arrayref
    return $self->error();
    
    # return all errors specific to the specified field (at the field-level)
    # as an arrayref
    return $self->error('some_param');
    
    # set an error specific to the specified field (at the field-level)
    # using the field object (hashref not field name)
    $self->error($field_object, "i am your error message");

    unless ($self->validate) {
        my $fields = $self->error();
    }

=head2 error_count

The error_count function returns the total number of error encountered from the 
last validation call.

    return $self->error_count();
    
    unless ($self->validate) {
        print "Found ". $self->error_count ." Errors";
    }

=head2 error_fields

The error_fields method returns a hashref of fields whose value is an arrayref
of error messages.

    unless ($self->validate) {
        my $bad_fields = $self->error_fields();
    }

=head2 errors_to_string

The errors_to_string function stringifies the error arrayref object using the
specified delimiter or ', ' by default. 

    return $self->errors_to_string();
    return $self->errors_to_string("<br/>\n");
    
    unless ($self->validate) {
        return $self->errors_to_string;
    }

=head2 get_params

The get_params method returns the values (in list form) of the parameters
specified.

    if ($self->validate) {
        my $name_a = $self->get_params('name');
        my ($name_b, $email, $login, $password) =
            $self->get_params(qw/name email login password/);
        
        # you should note that if the params dont exist they will return undef
        # ... meaning you should check that it exists before checking its value
        # e.g.
        
        if (defined $name) {
            if ($name eq '') {
                print 'name parameter was passed but was empty';
            }
        }
        else {
            print 'name parameter was never submitted';
        }
    }

=head2 get_params_hash

If your fields and parameters are designed with complex hash structures, The
get_params_hash method returns the deserialized hashref of specified parameters
based on the the default or custom configuration of the hash serializer
L<Hash::Flatten>.

    my $params = {
        'user.login' => 'member',
        'user.password' => 'abc123456'
    };
    
    if ($self->validate(keys %$params)) {
        my $params = $self->get_params_hash;
        print $params->{user}->{login};
    }

=head2 set_params_hash

Depending on how parameters are being input into your application, if your
input parameters are already complex hash structures, The set_params_hash method
will set and return the serialized version of your hashref based on the the
default or custom configuration of the hash serializer L<Hash::Flatten>.

    my $params = {
        user => {
            login => 'member',
            password => 'abc123456'
        }
    };
    
    my $serialized_params = $self->set_params_hash($params);

=head2 validate

The validate method returns true/false depending on whether all specified fields
passed validation checks. 

    use MyApp::Validation;
    
    my $input = MyApp::Validation->new(params => $params);
    
    # validate specific fields
    unless ($input->validate('field1','field2')){
        return $input->errors_to_string;
    }
    
    # validate all fields, regardless of parameter existence
    unless ($input->validate()){
        return $input->errors_to_string;
    }
    
    # validate all existing parameters
    unless ($input->validate(keys %{$input->params})){
        return $input->errors_to_string;
    }
    
    # validate specific parameters (by name) after mapping them to other fields
    my $map = {
        param1 => 'field_abc',
        param2 => 'field_def'
    };
    unless ($input->validate($map)){
        return $input->errors_to_string;
    }

=head2 reset_errors

The reset_errors method clears all errors, both at the class and individual
field levels. This method is called automatically everytime the validate()
method is triggered.

    $self->reset_errors();

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

