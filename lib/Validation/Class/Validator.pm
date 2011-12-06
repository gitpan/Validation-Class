# Input Validation and Parameter Handling Routines

use strict;
use warnings;

package Validation::Class::Validator;
{
    $Validation::Class::Validator::VERSION = '3.1.0';
}

our $VERSION = '3.1.0';    # VERSION

use Moose::Role;
use Array::Unique;
use Hash::Flatten;
use Hash::Merge 'merge';

# hash of directives
has 'directives' => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my $class = $_[0];

        return $class->can('config') ? $class->config->{DIRECTIVES} : {};
    }
);

# hash of fields
has 'fields' => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my $class = $_[0];

        return $class->can('config') ? $class->config->{FIELDS} : {};
    }
);

# switch: default filtering occurrence
has 'filtering' => (
    is      => 'rw',
    isa     => 'Maybe[Str]',
    default => 'pre'
);

# hash of filters
has 'filters' => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my $class = $_[0];

        return $class->can('config') ? $class->config->{FILTERS} : {};
    }
);

# Hash::Flatten args
has 'hash_inflator' => (
    is  => 'rw',
    isa => 'HashRef'
);

# message Hash::Flatten args
# regardless of case, convention, etc
around 'hash_inflator' => sub {
    my $orig    = shift;
    my $self    = shift;
    my $options = shift
      || {
        hash_delimiter  => '.',
        array_delimiter => ':',
        escape_sequence => '',
      };

    foreach my $option (keys %{$options}) {
        if ($option =~ /\_/) {
            my $cc_option = $option;

            $cc_option =~ s/([a-zA-Z])\_([a-zA-Z])/$1\u$2/gi;
            $options->{ucfirst $cc_option} = $options->{$option};

            delete $options->{$option};
        }
    }

    return $self->$orig($options);
};

# switch: ignore unknown parameters
has 'ignore_unknown' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0
);

# hash of mixins
has 'mixins' => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my $class = $_[0];

        return $class->can('config') ? $class->config->{MIXINS} : {};
    }
);

# input parameters store
has 'params' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} }
);

# hash of class plugins
has plugins => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my $class = $_[0];

        return $class->can('config') ? $class->config->{PLUGINS} : {};
    }
);

# class relatives (child-classes) store
has relatives => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} }
);

# switch: report unknown input parameters
has 'report_unknown' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0
);

# queue of field for (auto) validation
has 'stashed' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] }
);

# hash of directives by type
has 'types' => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my $class = $_[0];

        my $DRCTS = $class->directives;
        my $types = {mixin => {}, field => {}};

        # build types hash from directives by their usability
        while (my ($name, $directive) = each(%{$DRCTS})) {

            $types->{mixin}->{$name} = $directive if $DRCTS->{$name}->{mixin};
            $types->{field}->{$name} = $directive if $DRCTS->{$name}->{field};
        }

        return $types;
    }
);

# hackaroni tony
around BUILDARGS => sub {
    my ($code, $class, @args) = @_;

    my ($meta) = $class->meta;
    my $config = $meta->find_attribute_by_name('config');

    unless ($config) {
        $config = $meta->add_attribute(
            'config',
            'is'     => 'rw',
            'isa'    => 'HashRef',
            'traits' => ['Profile']
        );
        $config->{default} = sub {
            return $config->profile;
          }
    }

    # im not proud of this
    # this exists because I know not what I do
    # ... so what, fuck you dont use it :P

    return $class->$code(@args);
};

sub apply_filters {
    my ($self, $state) = @_;

    $state ||= 'pre';    # state defaults to (pre) filtering

    # check for and process input filters and default values
    while (my ($name, $field) = each(%{$self->fields})) {

        if ($field->{filtering} eq $state) {

            # the filters directive should always be an arrayref
            $field->{filters} = [$field->{filters}]
              unless "ARRAY" eq ref $field->{filters};

            # apply filters
            $self->use_filter($_, $name) for @{$field->{filters}};

            # set default value - absolute last resort
            if (defined $self->params->{$field}) {
                if (!$self->params->{$field}) {
                    if ($field->{default}) {
                        $self->params->{$field} = $field->{default};
                    }
                }
            }
        }
    }

    return $self;
}

# tie it all together after instantiation
sub BUILD {
    my $self = shift;

    # apply profile trait to config (if not already)
    unless (values %{$self->config}) {

        my $meta = $self->meta->find_attribute_by_name('config');
        $self->config($meta->profile);
    }

    # search for plugins to attach
    foreach my $plugin (keys %{$self->plugins}) {

        # init/setup hook in plugin
        $plugin->new($self) if $plugin->meta->has_method('new');

        # attach plugin
        $plugin->meta->apply($self);
    }

    # normalize environment - check validation class configuration objects and
    # structure, set default values, apply pre-filters, etc
    $self->normalize;
    $self->apply_filters('pre') if $self->filtering;

    return $self;
}

sub class {
    my ($self, $class, %args) = @_;

    my %defaults = (
        'params'         => $self->params,
        'ignore_unknown' => $self->ignore_unknown,
        'report_unknown' => $self->report_unknown,
        'hash_inflator'  => $self->hash_inflator
    );

    return $self->relatives->{$class}->new(merge(\%args, \%defaults));
}

sub check_field {
    my ($self, $field, $spec) = @_;

    my $directives = $self->types->{field};

    foreach (keys %{$spec}) {

        # if the field has a directive not listed in the directives table
        # errror !!!
        if (!defined $directives->{$_}) {
            my $death_cert = "The $_ directive supplied by the $field "
              . "field is not supported";

            $self->xxx_suicide_by_unknown_field($death_cert);
        }
    }

    return 1;
}

sub check_mixin {
    my ($self, $mixin, $spec) = @_;

    my $directives = $self->types->{mixin};

    foreach (keys %{$spec}) {
        if (!defined $directives->{$_}) {
            my $death_cert =
              "The $_ directive supplied by the $mixin mixin is not supported";
            $self->xxx_suicide_by_unknown_field($death_cert);
        }
        if (!$directives->{$_}) {
            my $death_cert =
              "The $_ directive supplied by the $mixin mixin is empty";
            $self->xxx_suicide_by_unknown_field($death_cert);
        }
    }

    return 1;
}

sub clone {
    my ($self, $field_name, $new_field_name, $directives) = @_;

    # build a new field from an existing one during runtime
    $self->fields->{$new_field_name} = $directives || {};
    $self->use_mixin_field($field_name, $new_field_name);

    return $self;
}

sub error {
    my ($self, @args) = @_;

    # set an error message on a particular field
    if (@args == 2) {

        # set error message
        my ($field, $error) = @args;

        # field must be a reference (hashref) to a field object
        if (ref($field) eq "HASH" && (!ref($error) && $error)) {

            # temporary, may break stuff
            $error = $field->{error} if defined $field->{error};

            # add error to field-level errors
            push @{$field->{errors}}, $error
              unless grep { $_ eq $error } @{$field->{errors}};

            # add error to class-level errors
            push @{$self->errors}, $error
              unless grep { $_ eq $error } @{$self->errors};
        }
        else {
            die "Can't set error without proper field and error "
              . "message data, field must be a hashref with name "
              . "and value keys";
        }
    }

    # retrieve an error message on a particular field
    if (@args == 1) {

        # return param-specific errors
        return $self->fields->{$args[0]}->{errors};
    }

    # return all class-level error messages
    return $self->errors;
}

sub error_fields {
    my ($self) = @_;

    my $error_fields = {};

    while (my ($name, $field) = each(%{$self->fields})) {

        if (@{$field->{errors}}) {
            $error_fields->{$name} = $field->{errors};
        }
    }

    return $error_fields;
}

sub get_params {
    my ($self, @params) = @_;

    # get param values as a list
    return map { $self->params->{$_} } @params;
}

sub get_params_hash {
    my ($self) = @_;

    my $serializer = Hash::Flatten->new($self->hash_inflator);
    my $params     = $serializer->unflatten($self->params);

    return $params;
}

# make the environment peaceful and sirene
sub normalize {
    my $self = shift;

    # automatically serialize params if nested hash is detected
    if (grep { ref($_) } values %{$self->params}) {
        $self->set_params_hash($self->params);
    }

    # reset fields
    $self->reset_fields;

    # validate mixin directives
    while (my ($name, $mixin) = each(%{$self->mixins})) {
        $self->check_mixin($name, $mixin);
    }

    # validate field directives and create default directives if needed
    while (my ($name, $field) = each(%{$self->fields})) {

        $self->check_field($name, $field);

        # by default fields should have a filters directive
        if (!defined $field->{filters}) {
            $field->{filters} = [];
        }

        # by default fields should have a filtering directive
        if (!defined $field->{filtering}) {
            $field->{filtering} = $self->filtering if $self->filtering;
        }

    }

    # check for and process a mixin directive
    while (my ($name, $field) = each(%{$self->fields})) {
        $self->use_mixin($name, $field->{mixin}) if $field->{mixin};
    }

    # check for and process a mixin_field directive
    while (my ($name, $field) = each(%{$self->fields})) {

        if ($field->{mixin_field}) {
            $self->use_mixin_field($field->{mixin_field}, $name)
              if $self->fields->{$field->{mixin_field}};
        }

    }

    # alias checking, ... for duplicate aliases, etc
    my $fieldtree = {};
    my $aliastree = {};

    while (my ($name, $field) = each(%{$self->fields})) {

        $fieldtree->{$name} = $name;    # just a counter

        if (defined $field->{alias}) {

            my $aliases =
              "ARRAY" eq ref $field->{alias}
              ? $field->{alias}
              : [$field->{alias}];

            foreach my $alias (@{$aliases}) {

                if ($aliastree->{$alias}) {
                    die "The field $field contains the alias $alias which is "
                      . "also defined in the field $aliastree->{$alias}";
                }
                elsif ($fieldtree->{$alias}) {
                    die "The field $field contains the alias $alias which is "
                      . "the name of an existing field";
                }
                else {
                    $aliastree->{$alias} = $field;
                }

            }

        }

    }

    # restore order to the land
    $self->reset_fields;

    return $self;
}

sub param {
    my ($self, $name, $value) = @_;

    return unless $name;

    $self->params->{$name} = $value if $value;

    return $self->params->{$name};
}

sub queue {
    my $self = shift;

    push @{$self->stashed}, @_;

    return $self;
}

sub set_params_hash {
    my ($self, $params) = @_;

    my $serializer = Hash::Flatten->new($self->hash_inflator);

    return $self->params($serializer->flatten($params));
}

sub reset {
    my $self = shift;

    $self->stashed([]);

    $self->reset_fields;

    return $self;
}

sub reset_errors {
    my $self = shift;

    $self->errors([]);

    foreach my $field (values %{$self->fields}) {
        $field->{errors} = [];
    }

    return $self;
}

sub reset_fields {
    my $self = shift;

    foreach my $field (keys %{$self->fields}) {

        # set default, special directives, etc
        $self->fields->{$field}->{name} = $field;
        $self->fields->{$field}->{'&toggle'} = undef;
        delete $self->fields->{$field}->{value};

    }

    $self->reset_errors();

    return $self;
}

sub use_filter {
    my ($self, $filter, $field) = @_;

    if (defined $self->params->{$field}) {

        if ($self->filters->{$filter} || "CODE" eq ref $filter) {

            if ($self->params->{$field}) {
                my $code =
                  "CODE" eq ref $filter ? $filter : $self->filters->{$filter};

                $self->fields->{$field}->{value} = $self->params->{$field} =
                  $code->($self->params->{$field});
            }

        }

    }

    return $self;
}

sub use_mixin {
    my ($self, $field, $mixin) = @_;

    # mixin values should be in arrayref form
    my $mixins = ref($mixin) eq "ARRAY" ? $mixin : [$mixin];

    foreach my $mixin (@{$mixins}) {

        if (defined $self->{mixins}->{$mixin}) {

            $self->fields->{$field} =
              $self->xxx_merge_field_with_mixin($self->fields->{$field},
                $self->{mixins}->{$mixin});

        }

    }

    return $self;
}

sub use_mixin_field {
    my ($self, $field, $target) = @_;

    $self->check_field($field, $self->fields->{$field});

    # name and label overwrite restricted
    my $name = $self->fields->{$target}->{name}
      if defined $self->fields->{$target}->{name};

    my $label = $self->fields->{$target}->{label}
      if defined $self->fields->{$target}->{label};

    $self->fields->{$target} =
      $self->xxx_merge_field_with_field($self->fields->{$target},
        $self->fields->{$field});

    $self->fields->{$target}->{name}  = $name  if defined $name;
    $self->fields->{$target}->{label} = $label if defined $label;

    foreach my $key (keys %{$self->fields->{$field}}) {
        $self->use_mixin($target, $key) if $key eq 'mixin';
    }

    return $self;
}

sub use_validator {
    my ($self, $field_name, $field) = @_;

    # does field have a label, if not use field name (e.g. for errors, etc)
    my $name = $field->{label} ? $field->{label} : $field_name;
    my $value = $field->{value};

    # check if required
    my $req = $field->{required} ? 1 : 0;

    if (defined $field->{'&toggle'}) {
        $req = 1 if $field->{'&toggle'} eq '+';
        $req = 0 if $field->{'&toggle'} eq '-';
    }

    if ($req && (!defined $value || $value eq '')) {
        my $error =
          defined $field->{error} ? $field->{error} : "$name is required";

        $self->error($field, $error);

        return $self;    # if required and fails, stop processing immediately
    }

    if ($req || $value) {

        # find and process all the validators
        foreach my $key (keys %{$field}) {

            my $directive = $self->directives->{$key};

            if ($directive) {

                if ($directive->{validator}) {

                    if ("CODE" eq ref $directive->{validator}) {

                        # execute validator directives
                        $directive->{validator}
                          ->($field->{$key}, $value, $field, $self);

                    }

                }

            }

        }

    }

    return $self;
}

sub validate {
    my ($self, @fields) = @_;

    # first things first, reset the errors and values, etc,
    # returning the validation class to its pristine state
    $self->normalize();
    $self->apply_filters('pre') if $self->filtering;
    $self->reset_fields();
    $self->reset_errors();

    # include fields stashed by the queue method
    if (@{$self->stashed}) {
        push @fields, @{$self->stashed};
    }

    # process field patterns
    my @new_fields = ();

    foreach my $field (@fields) {

        if ("Regexp" eq ref $field) {
            push @new_fields, grep { $_ =~ $field }
              sort keys %{$self->fields};
        }
        else {
            push @new_fields, $field;
        }

    }

    @fields = @new_fields;

    # process toggled fields
    foreach my $field (@fields) {

        my ($switch) = $field =~ /^([\-\+]{1})./;

        if ($switch) {

            # set fields toggle directive
            $field =~ s/^[\-\+]{1}//;
            $self->fields->{$field}->{'&toggle'} = $switch;
        }

    }

    # save unaltered state-of-parameters
    my %original_parameters = %{$self->params};

    # create alias map manually if requested
    # sorta DEPRECIATED
    if ("HASH" eq ref $fields[0]) {

        my $alias_map = $fields[0];
        @fields = ();    # blank

        while (my ($name, $alias) = each(%{$alias_map})) {

            $self->params->{$alias} = delete $self->params->{$name};
            push @fields, $alias;

        }

    }

    # create a map from aliases if applicable
    while (my ($name, $field) = each(%{$self->fields})) {

        if (defined $field->{alias}) {

            my $aliases =
              "ARRAY" eq ref $field->{alias}
              ? $field->{alias}
              : [$field->{alias}];

            foreach my $alias (@{$aliases}) {

                if (defined $self->params->{$alias}) {

                    $self->params->{$name} = delete $self->params->{$alias};
                    push @fields, $name;

                }

            }

        }

    }

    if (values %{$self->params}) {

        # validate all parameters against all defined fields because no fields
        # were explicitly requested to be validated
        if (!@fields) {

            # process all params
            while (my ($name, $param) = each(%{$self->params})) {

                if (!defined $self->fields->{$name}) {
                    $self->xxx_suicide_by_unknown_field(
                        "Data validation field $name does not exist");
                    next;
                }

                my $field = $self->fields->{$name};

                $field->{name} = $name;
                $field->{value} =
                  exists $self->params->{$name} ? $param : $field->{default}
                  || '';

                # create arguments to be passed to the validation directive
                my @args = ($self, $field, $self->params);

                # execute validator directives
                $self->use_validator($name, $field);

                # execute custom/validation directive
                if (defined $field->{validation} && $field->{value}) {

                    my $errcnt = $self->error_count;

                    unless ($field->{validation}->(@args)) {

                        # assuming the validation routine didnt issue an error
                        if ($errcnt == $self->error_count) {

                            if (defined $field->{error}) {
                                $self->error($field, $field->{error});
                            }
                            else {

                                my $error_msg =
                                  (($field->{label} || $field->{name})
                                    . " did not pass validation");

                                $self->error($field, $error_msg);

                            }

                        }

                    }

                }

            }

        }

        # validate all parameters against only the fields explicitly
        # requested to be validated
        else {

            foreach my $field_name (@fields) {

                if (!defined $self->fields->{$field_name}) {

                    $self->xxx_suicide_by_unknown_field(
                        "Data validation field $field_name does not exist");
                    next;

                }

                my $field = $self->fields->{$field_name};

                $field->{name} = $field_name;
                $field->{value} =
                  exists $self->params->{$field_name}
                  ? $self->params->{$field_name}
                  : $field->{default} || '';

                my @args = ($self, $field, $self->params);

                # execute simple validation
                $self->use_validator($field_name, $field);

                # custom validation
                if (defined $field->{validation} && $field->{value}) {

                    my $errcnt = $self->error_count;

                    unless ($field->{validation}->(@args)) {

                        # assuming the validation routine didnt issue an error
                        if ($errcnt == $self->error_count) {

                            if (defined $field->{error}) {
                                $self->error($field, $field->{error});
                            }
                            else {

                                my $error_msg =
                                  (($field->{label} || $field->{name})
                                    . " did not pass validation");

                                $self->error($field, $error_msg);

                            }

                        }

                    }

                }

            }

        }

    }
    else {

        # validate fields although no parameters were submitted
        # will likely pass validation unless fields exist with
        # a `required` directive or other validation logic
        # expecting a value
        if (@fields) {

            foreach my $field_name (@fields) {

                if (!defined $self->fields->{$field_name}) {

                    $self->xxx_suicide_by_unknown_field(
                        "Data validation field $field_name does not exist");
                    next;

                }

                my $field = $self->fields->{$field_name};

                $field->{name} = $field_name;
                $field->{value} =
                  exists $self->params->{$field_name}
                  ? $self->params->{$field_name}
                  : $field->{default} || '';

                my @args = ($self, $field, $self->params);

                # execute simple validation
                $self->use_validator($field_name, $field);

                # custom validation
                if (defined $field->{validation} && $field->{value}) {

                    my $errcnt = $self->error_count;

                    unless ($field->{validation}->(@args)) {

                        # assuming the validation routine didnt issue an error
                        if ($errcnt == $self->error_count) {

                            if (defined $field->{error}) {
                                $self->error($field, $field->{error});
                            }
                            else {

                                my $error_msg =
                                  (($field->{label} || $field->{name})
                                    . " did not pass validation");

                                $self->error($field, $error_msg);

                            }

                        }

                    }

                }

            }

        }

        # if no parameters (or) fields are found ... you're screwed :)
        # instead of dying, warn and continue, depending on configuration
        else {

            my $error =
                "No parameters were submitted and no fields are "
              . "registered. Fields and parameters are required "
              . "for proper validation.";

            if ($self->ignore_unknown) {
                if ($self->report_unknown) {
                    push @{$self->errors}, $error
                      unless grep { $_ eq $error } @{$self->errors};
                }
            }
            else {
                die $error;
            }

        }

    }

    my $valid = @{$self->errors} ? 0 : 1;

    # restore sanity
    $self->params({%original_parameters});

    # run post-validation filtering
    $self->apply_filters('post') if $self->filtering && $valid;

    return $valid;    # returns true if no errors
}

sub xxx_suicide_by_unknown_field {
    my ($self, $error) = @_;

    if ($self->ignore_unknown) {

        if ($self->report_unknown) {
            push @{$self->errors}, $error
              unless grep { $_ eq $error } @{$self->errors};
        }

    }
    else {
        die $error;
    }

}

sub xxx_merge_field_with_mixin {
    my ($self, $field, $mixin) = @_;

    while (my ($key, $value) = each(%{$mixin})) {

        # do not override existing keys but multi values append
        if (grep { $key eq $_ } keys %{$field}) {
            next unless $self->types->{field}->{$key}->{multi};
        }

        if (defined $self->types->{field}->{$key}) {

            # can the directive have multiple values, merge array
            if ($self->types->{field}->{$key}->{multi}) {

                # if field has existing array value, merge unique
                if ("ARRAY" eq ref $field->{$key}) {

                    tie my @values, 'Array::Unique';

                    push @{$field->{$key}},
                      "ARRAY" eq ref $value ? @{$value} : $value;

                    $field->{$key} = [@{$field->{$key}}];

                }

                # merge copy
                else {

                    tie my @values, 'Array::Unique';

                    @values = "ARRAY" eq ref $value ? @{$value} : ($value);

                    push @values, $field->{$key} if $field->{$key};

                    $field->{$key} = [@values];

                }
            }

            # simple copy
            else {
                $field->{$key} = $value;
            }

        }

    }

    return $field;
}

sub xxx_merge_field_with_field {
    my ($self, $field, $mixin_field) = @_;

    while (my ($key, $value) = each(%{$mixin_field})) {

        # skip unless the directive is mixin compatible
        next unless $self->types->{mixin}->{$key}->{mixin};

        # do not override existing keys but multi values append
        if (grep { $key eq $_ } keys %{$field}) {
            next unless $self->types->{field}->{$key}->{multi};
        }

        if (defined $self->types->{field}->{$key}) {

            # can the directive have multiple values, merge array
            if ($self->types->{field}->{$key}->{multi}) {

                # if field has existing array value, merge unique
                if ("ARRAY" eq ref $field->{key}) {

                    tie my @values, 'Array::Unique';

                    push @{$field->{$key}},
                      "ARRAY" eq ref $value ? @{$value} : $value;

                    $field->{$key} = [@{$field->{$key}}];
                }

                # simple copy
                else {

                    $field->{$key} =
                      "ARRAY" eq ref $value ? [@{$value}] : $value;

                }

            }

            # simple copy
            else {
                $field->{$key} = $value;
            }

        }

    }

    return $field;
}

no Moose::Role;

1;
