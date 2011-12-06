# ABSTRACT: Centralized Data Validation Framework

use strict;
use warnings;

package Validation::Class;
{
    $Validation::Class::VERSION = '3.1.0';
}

use 5.008001;

our $VERSION = '3.1.0';    # VERSION

use Moose ('has');
use Moose::Exporter;
use MooseX::Traits;
use Validation::Class::Sugar ();

my ($import, $unimport, $init_meta) = Moose::Exporter->build_import_methods(
    also => ['Moose', 'Validation::Class::Sugar'],
    base_class_roles =>
      ['Validation::Class::Errors', 'Validation::Class::Validator',],
);

sub init_meta {
    my ($dummy, %opts) = @_;

    Moose->init_meta(%opts);

    Moose::Util::MetaRole::apply_base_class_roles(
        for   => $opts{for_class},
        roles => [
            'MooseX::Traits', 'Validation::Class::Errors',
            'Validation::Class::Validator',
        ]
    );

    return Class::MOP::class_of($opts{for_class});
}

sub import {
    return unless $import;
    goto &$import;
}

sub unimport {
    return unless $unimport;
    goto &$unimport;
}

# REGISTER TRAITS - Escape the PAUSE

{

    # Profile Trait
    package    # Don't register with PAUSE (pause.perl.org)
      Moose::Meta::Attribute::Custom::Trait::Profile;

    sub register_implementation {
        my $pkg = 'Validation_Class_Meta_Attribute_Profile';
        $pkg =~ s/_/::/g;
        $pkg;
    }
}

# BEGIN MEGA-POD


1;
__END__

=pod

=head1 NAME

Validation::Class - Centralized Data Validation Framework

=head1 VERSION

version 3.1.0

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
    fld 'login'  => {
        label      => 'User Login',
        error      => 'Login invalid.',
        required   => 1,
        validation => sub {
            my ($self, $this_field, $all_params) = @_;
            return $this_field->{value} eq 'admin' ? 1 : 0;
        }
    };
    
    # a validation rule
    fld 'password'  => {
        label         => 'User Password',
        error         => 'Password invalid.',
        required      => 1,
        validation    => sub {
            my ($self, $this_field, $all_params) = @_;
            return $this_field->{value} eq 'pass' ? 1 : 0;
        }
    };
    
    1;

The fields defined will be used to validate the specified input parameters.
You specify the input parameters at instantiation, parameters should take the
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

The mixin keyword (or mxn) creates a validation rules template that can be applied to any
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

The filter keyword (or flt) creates custom filters to be used in your field definitions.

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

The directive keyword (or dir) creates custom validator directives to be used in your field
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

The field keyword (or fld) creates a validation block and defines validation rules for
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

The field keyword takes two arguments, the field name and a hashref of key/values
pairs.

=head1 FILTERING INCOMING DATA

Validation::Class supports pre/post filtering but is configured to pre-filter
incoming data. This means that based upon the filtering options supplied within
the individual fields, filtering will happen before validation (technically at
instantiation and again just before validation). As expected, this is configurable
via the filtering attribute.

A WORD OF CAUTION: Validation::Class is configured to pre-filter incoming data
which boosts application security and is best used with passive filtering 
(e.g. converting character case - filtering which only alters the input in
predictable ways), versus aggressive filtering (e.g. formatting a telephone
number) which completely and permanently changes the incoming data ... so much
so that if the validation still fails ... errors that are reported may not
match the data that was submitted.

If you're sure you'd rather employ aggressive filtering, I suggest setting
the filtering attribute to 'post' for post-filtering or setting it to '' non
and applying the filters manually via apply_filters().

=head1 AUTO-SERIALIZATION/DESERIALIZATION

Validation::Class supports hash automatic serialization/deserialization
which means that you can set the parameters using a hashref of nested
hashrefs and validate against them, or set the parameters using a hashref of
key/value pairs and validate against that. This function is provided in
Validation::Class via L<Hash::Flatten>. The following is an example of that:

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
    
    # field definition using field('user.login', ...)
    # and field('user.password', ...) will match against the parameters above
    
    # after filtering, validation, etc ... return your params as a hashref if
    # needed
    
    my $params = $rules->get_params_hash;

=head1 SEPERATION OF CONCERNS

For larger applications were a single validation class might become cluttered
and inefficient Validation::Class come equipped to help you separate your
validation rules into separate classes.

The idea is that you'll end up with a main validation class (most-likely empty)
that will simply serve as your point of entry into your relative (child)
classes. The following is an example of this:

    package MyVal::User;
    use Validation::Class;
    
    field name => { ... };
    field email => { ... };
    field login => { ... };
    field password => { ... };
    
    package MyVal::Profile;
    use Validation::Class;
    
    field age => { ... };
    field sex => { ... };
    field birthday => { ... };
    
    package MyVal;
    use Validation::Class;
    
    __PACKAGE__->load_classes;
    
    package main;
    
    my $rules = MyVal->new(params => $params);
    my $user = $rules->class('user');
    my $profile = $rules->class('profile');
    
    ...
    
    1;

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

=head2 default

The default directive is used as a default value for a field to be used
when a matching parameter is not present.

    # the default directive
    field 'quantity'  => {
        default => 1,
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

=head2 filtering

The filtering directive is used to control when field filters are applied. The
default recognized values are pre/post. A value of 'pre' instructs the validation
class to apply the field's filters at instatiation and before validation whereas
a value of 'post' instructs the validation class to apply the field's filters
after validation. Alternatively, a value of undef or '' will bypass filtering
altogether.

    # the filtering directive
    field 'foobar'  => {
        filtering => 'post',
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
effect and *in-fact* all filtering, validation, etc is then skipped.

    # the required directive
    field 'foobar'  => {
        required => 1,
        ...
    };
    
    # fail
    my $rules = MyApp::Validation->new(params => {  });
    $rules->validate('foobar');
    
    # pass
    my $rules = MyApp::Validation->new(params => {  foobar => 'Nii=cce' });
    $rules->validate('foobar');

See the toggle functionality within the validate() method. This method allows
you to temporarily alter whether a field is required or not.

=head2 validation

The validation directive is a coderef used add additional custom validation to
the field.

    # the validation directive
    field 'login'  => {
        validation => sub {
            my ($self, $this_field, $all_params) = @_;
            return 0 unless $this_field->{value};
            return $this_field->{value} eq 'admin' ? 1 : 0;
        },
        ...
    };

=head2 value

The value directive is used internally to store the field's matching parameter's
value. This value can be set in the definition but SHOULD NOT be used as a
default value unless you're sure no parameter will overwrite it during runtime.
If you need to set a default value, see the default directive.

    # the value directive
    field 'quantity'  => {
        value => 1,
        ...
    };

=head1 DEFAULT FIELD/MIXIN FILTER DIRECTIVES

=head2 filters

The filters directive is used to correct, altering and/or format the
values of the matching input parameter. Note: Filtering is applied before
validation. The filter directive can have multiple filters (even a coderef)
in the form of an arrayref of values.

    # the filter(s) directive
    field 'text'  => {
        filters => [qw/trim strip/ => sub {
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
where sentences are separated by a period and space, within the field's value.

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
white-spaces from the field's value and additionally removes multiple white-spaces
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

The trim filter removes leading and trailing white-spaces from the field's value.

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

=head2 depends_on

    # the depends_on directive
    field 'change_password'  => {
        depends_on => ['password', 'password_confirm'],
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

=head2 max_alpha

    # the max_alpha directive
    field 'password'  => {
        max_alpha => 30,
        ...
    };

=head2 max_digits

    # the max_digits directive
    field 'password'  => {
        max_digits => 5,
        ...
    };

=head2 max_length

    # the max_length directive
    field 'foobar'  => {
        max_length => '...',
        ...
    };

=head2 max_sum

    # the max_sum directive
    field 'vacation_days'  => {
        max_sum => 5,
        ...
    };

=head2 max_symbols

    # the max_symbols directive
    field 'password'  => {
        max_symbols => 1,
        ...
    };

=head2 min_alpha

    # the min_alpha directive
    field 'password'  => {
        min_alpha => 2,
        ...
    };

=head2 min_digits

    # the min_digits directive
    field 'password'  => {
        min_digits => 1,
        ...
    };

=head2 min_length

    # the min_length directive
    field 'foobar'  => {
        min_length => '...',
        ...
    };

=head2 min_sum

    # the min_sum directive
    field 'vacation_days'  => {
        min_sum => 0,
        ...
    };

=head2 min_symbols

    # the min_symbols directive
    field 'password'  => {
        min_symbols => 0,
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
        # simple pattern
        pattern => '### ###-####',
        ...
    };
    
    field 'country_code'  => {
        # simple pattern
        pattern => 'XX',
        filter  => 'uppercase'
        ...
    };
    
    field 'complex'  => {
        # regex pattern
        pattern => qr/[0-9]+\,\s\.\.\./,
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
with their parameter counterparts.

    my $self = MyApp::Validation->new(fields => $fields);
    my $fields = $self->fields();
    ...

=head2 filtering

The filtering attribute (by default set to 'pre') controls when incoming data
is filtered. Setting this attribute to 'post' will defer filtering until after
validation which allows any errors messages to report errors based on the
unaltered data. Alternatively, setting the filtering attribute to '' or undef
will bypass all filtering unless explicitly defined at the field-level.

    my $self = MyApp::Validation->new(filtering => 'post');
    $self->validate();
    ...

=head2 filters

The filters attribute returns a hashref of pre-defined filter definitions.

    my $filters = $self->filters();
    ...

=head2 hash_inflator

The hash_inflator value determines how the hash serializer (inflation/deflation)
behaves. The value must be a hashref of L<Hash::Flatten/OPTIONS> options. Purely
for the sake of consistency, you can use lowercase keys (with underscores) which
will be converted to camel-cased keys before passed to the serializer.

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

=head2 stashed

The stashed attribute represents a list of field names stored to be used in
validation later. If the stashed attribute contains a list you can omit
arguments to the validate method. 

    $self->stashed([qw/this that .../]);

=head1 VALIDATION CLASS METHODS

=head2 apply_filters

The apply_filters method (usually called automatically based on the filtering
attribute) can be used to run the currently defined parameters through the
filters defined in the fields.

    my $rules = MyVal->new(filtering => '', params => $params);
    
    if ($rules->validate) {
        $rules->apply_filters;
    }
    else {
        print $rules->errors_to_string;
        # print errors on unaltered parameters
    }

=head2 class

The class method returns a new initialize child validation class under the
namespace of the calling class that issued the load_classes() method call.
Existing parameters and configuration options are passed to the child class's
constructor. All attributes can be easily overwritten using the attribute's
accessors on the child class.

    package MyVal;
    use Validation::Class; __PACKAGE__->load_classes;
    
    package main;
    
    my $rules = MyVal->new(params => $params);
    
    my $kid1 = $rules->class('Child'); # loads MyVal::Child;
    my $kid2 = $rules->class('StepChild'); # loads MyVal::StepChild;
    
    my $kid3 = $rules->class('child'); # loads MyVal::Child;
    my $kid4 = $rules->class('step_child'); # loads MyVal::StepChild;
    
    1;

=head2 clone

The clone method is used to create new fields (rules) from existing fields
on-the-fly. This is useful when you have a variable number of parameters being
validated that can share existing validation rules. E.g., a web-form on a user's
profile page may have dynamically created input boxes for the person's phone
numbers allowing the user to add additional parameters to the web-form as
needed, in that case as opposed to having multiple validation rules hardcoded
for each parameter, you could hardcode one single rule and clone the rule at
runtime.

    package MyVal;
    use Validation::Class;
    
    field phone => { required => 1 };
    
    package main;
    
    my $rules = MyVal->new(params => $params);
    
    # clone phone rule at runtime to validate dynamically created parameters
    $rules->clone('phone', 'phone2', { label => 'Other Phone', required => 0 });
    $rules->clone('phone', 'phone3', { label => 'Third Phone', required => 0 });
    $rules->clone('phone', 'phone4', { label => 'Forth Phone', required => 0 });
    
    $rules->validate(qw/phone phone2 phone3 phone4/);
    
    1;

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

=head2 load_classes

The load_classes method is used L<Module::Find> to load child classes for
convenient access through the class() method. Existing parameters and
configuration options are passed to the child class's constructor. All
attributes can be easily overwritten using the attribute's accessors on the
child class.

    package MyVal;
    use Validation::Class; __PACKAGE__->load_classes;
    1;

=head2 load_plugins

The load_plugins method is used to load plugins that support Validation::Class. 
A Validation::Class plugin is little more than a Role (Moose::Role) that extends
the Validation::Class core. As usual, an official Validation::Class plugin can
be referred to using shorthand while custom plugins are called by prefixing a
plus symbol to the fully-qualified plugin name. Learn more about plugins at
L<Validation::Class::Plugins>.

    package MyVal;
    use Validation::Class;
    
    __PACKAGE__->load_plugins('SuperX');
    # loads Validation::Class::Plugin::SuperX
    
    __PACKAGE__->load_plugins('+MyApp::Validation::Plugin::SuperY');
    
    1;

=head2 param

The param method returns a single parameter by name.

    if ($self->param('chng_pass')) {
        $self->validate('password_confirmation');
    }

=head2 queue

The queue method is a convenience method used specifically to append the
stashed attribute allowing you to *queue* field to be validated. This method
also allows you to set fields that must always be validated. 

    # conditional validation flow WITHOUT the queue method
    # imagine a user profile update action
    
    my $rules = MyApp::Validation->new(params => $params);
    my @fields = qw/name login/;
    
    push @fields, 'email_confirm' if $rules->param('chg_email');
    push @fields, 'password_confirm' if $rules->param('chg_pass');
    
    ... if $rules->validate(@fields);
    
    # conditional validation WITH the queue method
    
    my $rules = MyApp::Validation->new(params => $params);
    
    $rules->queue(qw/name login/);
    $rules->queue(qw/email_confirm/) if $rules->param('chg_email');
    $rules->queue(qw/password_confirm/) if $rules->param('chg_pass');
    
    ... if $rules->validate();
    
    # set fields that must ALWAYS be validated
    # imagine a simple REST server
    
    my $rules = MyApp::Validation->new(params => $params);
    
    $rules->queue(qw/login password/);
    
    if ($request eq '/resource/:id') {
        
        if ($rules->validate('id')) {
            
            # validated login, password and id
            ...
        }
    }

=head2 reset

The reset method clears all errors, fields and stashed field names, both at the
class and individual field levels.

    $self->reset();

=head2 reset_errors

The reset_errors method clears all errors, both at the class and individual
field levels. This method is called automatically everytime the validate()
method is triggered.

    $self->reset_errors();

=head2 reset_fields

The reset_fields method clears all errors and field values, both at the class
and individual field levels. This method is executed automatically at
instantiation.

    $self->reset_fields();

=head2 sanitize

The sanitize method executes a set of routines that reset the parameter
environment filtering any parameters present. This method is executed
automatically at instantiation and validation. 

    $self->sanitize();

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
    
    # validate fields based on a regex pattern
    unless ($input->validate(qr/^field(\d+)?/)){
        return $input->errors_to_string;
    }
    
    # validate existing parameters, if no parameters exist,
    # validate all fields ... which will return true unless field(s) exist
    # with a required directive
    unless ($input->validate()){
        return $input->errors_to_string;
    }
    
    # validate all fields period, obviously
    unless ($input->validate(keys %{$input->fields})){
        return $input->errors_to_string;
    }
    
    # validate specific parameters (by name) after mapping them to other fields
    my $parameter_map = {
        user => 'hey_im_not_named_login',
        pass => 'password_is_that_really_you'
    };
    unless ($input->validate($parameter_map)){
        return $input->errors_to_string;
    }

Another cool trick the validate() method can perform is the ability to temporarily
alter whether a field is required or not during runtime. This functionality is
often referred to as the *toggle* function.

This function is important when you define a field (or two or three) as required
or non and want to change that per validation. This is done by calling the
validate() method with a list of fields to be validated and prefixing the
target fields with a plus or minus as follows:

    use MyApp::Validation;
    
    my $input = MyApp::Validation->new(params => $params);
    
    # validate specific fields, force name, email and phone to be required
    # regardless of the field definitions directives ... and force the age, sex
    # and birthday to be optional
    
    my @spec = qw(+name +email +phone -age -sex -birthday);
    
    unless ($input->validate(@spec)){
        return $input->errors_to_string;
    }

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

