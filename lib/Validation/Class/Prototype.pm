# ABSTRACT: Prototype and Data Validation Engine for Validation::Class

package Validation::Class::Prototype;
{
    $Validation::Class::Prototype::VERSION = '7.72';
}

use strict;
use warnings;

our $VERSION = '7.72';    # VERSION

use base 'Validation::Class::Backwards';    # I'm pro-life

use Carp 'confess';
use Hash::Merge 'merge';
use Module::Runtime 'use_module';
use Hash::Flatten;

use Validation::Class::Base 'has', 'hold';
use Validation::Class::Params;
use Validation::Class::Errors;
use Validation::Class::Fields;


# is never changed so direct access is OK
hold 'directives' => sub { shift->{config}->{DIRECTIVES} || {} };


hold 'errors' => sub { [] };


hold 'fields' => sub { {} };


has 'filtering' => 'pre';


hold 'filters' => sub { {} };


has 'hash_inflator' => sub {

    my $options = @_ > 1
      ? pop @_
      : {
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

    return $options;

};


has 'ignore_failure' => '1';


has 'ignore_unknown' => '0';


hold 'methods' => sub { {} };


hold 'mixins' => sub { {} };


hold 'params' => sub { {} };


has plugins => sub { {} };


hold 'profiles' => sub { {} };


has 'queued' => sub { [] };


# class relatives (child-classes) store
hold 'relatives' => sub { {} };


# switch: report method requirement failures
has 'report_failure' => 0;


# switch: report unknown input parameters
has 'report_unknown' => 0;

# stash object storage
has 'stashed' => sub { {} };

# hash of directives by type
hold 'types' => sub {

    my $self  = shift;
    my $types = {mixin => {}, field => {}};
    my $dirts = $self->directives;

    # build types hash from directives by their usability
    while (my ($name, $directive) = each(%{$dirts})) {

        $types->{mixin}->{$name} = $directive if $dirts->{$name}->{mixin};
        $types->{field}->{$name} = $directive if $dirts->{$name}->{field};

    }

    return $types;

};

sub apply_filter {

    my ($self, $filter, $field) = @_;

    if ($self->params->has($field)) {

        if ($self->filters->{$filter} || "CODE" eq ref $filter) {

            if ($self->params->{$field}) {

                my $code =
                  "CODE" eq ref $filter ? $filter : $self->filters->{$filter};

                $self->set_value($field => $code->($self->params->{$field}));

            }

        }

    }

    return $self;

}


sub apply_filters {

    my ($self, $state) = @_;

    $state ||= 'pre';    # state defaults to (pre) filtering

    # check for and process input filters and default values
    my $process = sub {

        my ($name, $config) = @_;

        if ($config->filtering eq $state) {

            # the filters directive should always be an arrayref
            $config->filters([$config->filters])
              unless "ARRAY" eq ref $config->filters;

            # apply filters
            $self->apply_filter($_, $name) for @{$config->filters};

            # set default value - absolute last resort
            if ($self->params->has($name)) {

                if (!$self->params->{$name}) {

                    if (defined $config->{default}) {

                        $self->params->{$name} = $self->get_value($name);

                    }

                }

            }

        }

    };

    $self->fields->each($process);

    return $self;

}

sub apply_mixin {

    my ($self, $field, $mixin) = @_;

    # mixin values should be in arrayref form

    my $mixins = ref($mixin) eq "ARRAY" ? $mixin : [$mixin];

    foreach my $mixin (@{$mixins}) {

        if (defined $self->{mixins}->{$mixin}) {

            $self->fields->{$field} =
              $self->merge_mixin($self->fields->{$field},
                $self->{mixins}->{$mixin});

        }

    }

    return $self;

}

sub apply_mixin_field {

    my ($self, $field, $target) = @_;

    $self->check_field($field, $self->fields->{$field});

    # some overwriting restricted

    my $name = $self->fields->{$target}->{name}
      if defined $self->fields->{$target}->{name};

    my $label = $self->fields->{$target}->{label}
      if defined $self->fields->{$target}->{label};

    # merge

    $self->fields->{$target} =
      $self->merge_field($self->fields->{$target}, $self->fields->{$field});

    # restore

    $self->fields->{$target}->{name}  = $name  if defined $name;
    $self->fields->{$target}->{label} = $label if defined $label;

    foreach my $key (keys %{$self->fields->{$field}}) {

        $self->apply_mixin($target, $key) if $key eq 'mixin';

    }

    return $self;

}

sub apply_validator {

    my ($self, $field_name, $field) = @_;

    # does field have a label, if not use field name (e.g. for errors, etc)

    my $name = $field->{label} ? $field->{label} : $field_name;
    my $value = $field->{value};

    # check if required

    my $req = $field->{required} ? 1 : 0;

    if (defined $field->{':toggle'}) {

        $req = 1 if $field->{':toggle'} eq '+';
        $req = 0 if $field->{':toggle'} eq '-';

    }

    if ($req && (!defined $value || $value eq '')) {

        my $error =
          defined $field->{error} ? $field->{error} : "$name is required";

        $field->{errors}->add($error);

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

sub check_field {

    my ($self, $name, $spec) = @_;

    my $directives = $self->types->{field};

    foreach (keys %{$spec}) {

        # check if the field's directives are registered

        if (!defined $directives->{$_}) {

            my $error = qq{
                The $_ directive supplied by the $name field is not supported
            };

            $self->pitch_error($error);

        }

    }

    return 1;

}

sub check_mixin {

    my ($self, $mixin, $spec) = @_;

    my $directives = $self->types->{mixin};

    foreach (keys %{$spec}) {

        if (!defined $directives->{$_}) {

            my $error = qq{
                The $_ directive supplied by the $mixin mixin is not supported
            };

            $self->pitch_error($error);

        }

        if (!$directives->{$_}) {

            my $error = qq{
                The $_ directive supplied by the $mixin mixin is empty
            };

            $self->pitch_error($error);

        }

    }

    return 1;

}


sub class {

    my $self = shift;

    my ($class, %args);

    if (@_ % 2) {

        ($class, %args) = @_;

    }

    else {

        %args  = @_;
        $class = $args{'-name'};    # i hate this convention, not ideal but...
        delete $args{'-name'};

    }

    return 0 unless $class;

    my $shortname;

    # transform what looks like a shortname

    if ($class !~ /::/) {

        $shortname = $class;

        my @parts = split /[^0-9A-Za-z_]/, $class;

        foreach my $part (@parts) {

            $part = ucfirst $part;
            $part =~ s/([a-z])_([a-z])/$1\u$2/g;

        }

        $class = join "::", @parts;

    }

    else {

        $shortname = $class;
        $shortname =~ s/([a-z])([A-Z])/$1_$2/g;
        $shortname =~ s/::/\./g;
        $shortname = lc $shortname;

    }

    return 0 unless defined $self->relatives->{$class};

    my @attrs = qw(

      hash_inflator
      ignore_failure
      ignore_unknown
      report_failure
      report_unknown

      );    # to be copied (stash and params copied later)

    my $delimiter = $self->hash_inflator->{'HashDelimiter'};

    my %defaults = (map { $_ => $self->$_ } @attrs);

    $defaults{'stash'} = $self->stash;    # copy stash

    $defaults{'params'} = $self->get_params;    # copy params

    my %settings = %{merge \%args, \%defaults};

    my $class_name = $self->relatives->{$class};

    use_module $class_name;

    for (keys %settings) {

        delete $settings{$_} unless $class_name->can($_);

    }

    my $child = $class_name->new(%settings);

    my $proto = $child->proto;

    if (defined $settings{'params'}) {

        $delimiter =~ s/([\.\+\-\:\,\\\/])/\\$1/g;

        foreach my $name ($proto->params->keys) {

            if ($name =~ /^$shortname$delimiter(.*)/) {

                if ($proto->fields->has($1)) {

                    push @{$proto->fields->{$1}->{alias}}, $name;

                }

            }

        }

    }

    return $child;

}


sub clear_queue {

    my $self = shift @_;

    my @names = @{$self->queued};

    $self->queued([]);

    for (my $i = 0; $i < @names; $i++) {

        $names[$i] =~ s/^[\-\+]{1}//;
        $_[$i] = $self->param($names[$i]);

    }

    return @_;

}


sub clone {

    my ($self, $field_name, $new_field_name, $directives) = @_;

    $directives ||= {};

    $directives->{name} = $new_field_name unless $directives->{name};

    # build a new field from an existing one during runtime
    $self->fields->{$new_field_name} =
      Validation::Class::Field->new($directives);

    $self->apply_mixin_field($field_name, $new_field_name);

    return $self;

}

sub configuration {

    return {

        ATTRIBUTES => {},

        BUILDERS => [],

        DIRECTIVES => {

            ':toggle' => {

                mixin => 0,
                field => 1,
                multi => 0

            },

            alias => {

                mixin => 0,
                field => 1,
                multi => 1

            },

            between => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_between

            },

            default => {

                mixin => 1,
                field => 1,
                multi => 1

            },

            depends_on => {

                mixin => 1,
                field => 1,
                multi => 1,

                validator => \&configuration_validator_depends_on

            },

            error => {

                mixin => 0,
                field => 1,
                multi => 0

            },

            errors => {

                mixin => 0,
                field => 1,
                multi => 0

            },

            filters => {

                mixin => 1,
                field => 1,
                multi => 1

            },

            filtering => {

                mixin => 1,
                field => 1,
                multi => 1

            },

            label => {

                mixin => 0,
                field => 1,
                multi => 0

            },

            length => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_length

            },

            matches => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_matches

            },

            max_alpha => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_max_alpha

            },

            max_digits => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_max_digits

            },

            max_length => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_max_length

            },

            max_sum => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_max_sum

            },

            max_symbols => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_max_symbols

            },

            min_alpha => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_min_alpha

            },

            min_digits => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_min_digits

            },

            min_length => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_min_length

            },

            min_sum => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_min_sum

            },

            min_symbols => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_min_symbols

            },

            mixin => {

                mixin => 0,
                field => 1,
                multi => 1

            },

            mixin_field => {

                mixin => 0,
                field => 1,
                multi => 0

            },

            name => {

                mixin => 0,
                field => 1,
                multi => 0

            },

            options => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_options

            },

            pattern => {

                mixin => 1,
                field => 1,
                multi => 0,

                validator => \&configuration_validator_pattern

            },

            readonly => {

                mixin => 0,
                field => 1,
                multi => 0

            },

            required => {

                mixin => 1,
                field => 1,
                multi => 0

            },

            validation => {

                mixin => 0,
                field => 1,
                multi => 0

            },

            value => {

                mixin => 1,
                field => 1,
                multi => 1

              }

        },

        FIELDS => {},

        FILTERS => {

            alpha => sub {

                $_[0] =~ s/[^A-Za-z]//g;
                $_[0];

            },

            alphanumeric => sub {

                $_[0] =~ s/[^A-Za-z0-9]//g;
                $_[0];

            },

            capitalize => sub {

                $_[0] = ucfirst $_[0];
                $_[0] =~ s/\.\s+([a-z])/\. \U$1/g;
                $_[0];

            },

            decimal => sub {

                $_[0] =~ s/[^0-9\.\,]//g;
                $_[0];

            },

            lowercase => sub {

                lc $_[0];

            },

            numeric => sub {

                $_[0] =~ s/\D//g;
                $_[0];

            },

            strip => sub {

                $_[0] =~ s/\s+/ /g;
                $_[0] =~ s/^\s+//;
                $_[0] =~ s/\s+$//;
                $_[0];

            },

            titlecase => sub {

                join(" ", map (ucfirst, split(/\s/, lc $_[0])));

            },

            trim => sub {

                $_[0] =~ s/^\s+//g;
                $_[0] =~ s/\s+$//g;
                $_[0];

            },

            uppercase => sub {

                uc $_[0];

              }

        },

        METHODS => {},

        MIXINS => {},

        PLUGINS => {},

        PROFILES => {},

        RELATIVES => {},

      }

}

sub configuration_validator_between {

    my ($directive, $value, $field, $class) = @_;

    my ($min, $max) =
      "ARRAY" eq ref $directive
      ? @{$directive}
      : split /(?:\s{1,})?[,\-]{1,}(?:\s{1,})?/, $directive;

    $min = scalar($min);
    $max = scalar($max);

    $value = length($value);

    if (defined $value) {

        unless ($value >= $min && $value <= $max) {

            my $handle = $field->{label} || $field->{name};
            my $error = "$handle must contain between $directive characters";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_depends_on {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        my $dependents = "ARRAY" eq ref $directive ? $directive : [$directive];

        if (@{$dependents}) {

            my @blanks = ();

            foreach my $dep (@{$dependents}) {

                push @blanks, $class->fields->{$dep}->{label}
                  || $class->fields->{$dep}->{name}
                  if !$class->param($dep);

            }

            if (@blanks) {

                my $handle = $field->{label} || $field->{name};

                my $error =
                    "$handle requires "
                  . join(", ", @blanks)
                  . " to have "
                  . (@blanks > 1 ? "values" : "a value");

                $field->errors->add($field->{error} || $error);

                return 0;

            }

        }

    }

    return 1;

}

sub configuration_validator_length {

    my ($directive, $value, $field, $class) = @_;

    $value = length($value);

    if (defined $value) {

        unless ($value == $directive) {

            my $handle = $field->{label} || $field->{name};
            my $characters = $directive > 1 ? "characters" : "character";

            my $error =
              "$handle must contain exactly " . "$directive $characters";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_matches {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        # build the regex
        my $this = $value;
        my $that = $class->param($directive) || '';

        unless ($this eq $that) {

            my $handle = $field->{label} || $field->{name};
            my $handle2 = $class->fields->{$directive}->{label}
              || $class->fields->{$directive}->{name};

            my $error = "$handle does not match $handle2";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_max_alpha {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        my @i = ($value =~ /[a-zA-Z]/g);

        unless (@i <= $directive) {

            my $handle = $field->{label} || $field->{name};
            my $characters = int($directive) > 1 ? "characters" : "character";

            my $error = "$handle must contain at-least "
              . "$directive alphabetic $characters";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_max_digits {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        my @i = ($value =~ /[0-9]/g);

        unless (@i <= $directive) {

            my $handle = $field->{label} || $field->{name};
            my $characters = int($directive) > 1 ? "digits" : "digit";

            my $error =
              "$handle must contain at-least " . "$directive $characters";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_max_length {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        unless (length($value) <= $directive) {

            my $handle = $field->{label} || $field->{name};
            my $characters = int($directive) > 1 ? "characters" : "character";

            my $error =
              "$handle can't contain more than " . "$directive $characters";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_max_sum {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        unless ($value <= $directive) {

            my $handle = $field->{label} || $field->{name};
            my $error = "$handle can't be greater than " . "$directive";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_max_symbols {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        my @i = ($value =~ /[^0-9a-zA-Z]/g);

        unless (@i <= $directive) {

            my $handle = $field->{label} || $field->{name};
            my $characters = int($directive) > 1 ? "symbols" : "symbol";

            my $error =
              "$handle can't contain more than " . "$directive $characters";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_min_alpha {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        my @i = ($value =~ /[a-zA-Z]/g);

        unless (@i >= $directive) {

            my $handle = $field->{label} || $field->{name};
            my $characters = int($directive) > 1 ? "characters" : "character";

            my $error = "$handle must contain at-least "
              . "$directive alphabetic $characters";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_min_digits {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        my @i = ($value =~ /[0-9]/g);

        unless (@i >= $directive) {

            my $handle = $field->{label} || $field->{name};
            my $characters = int($directive) > 1 ? "digits" : "digit";

            my $error =
              "$handle must contain at-least " . "$directive $characters";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_min_length {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        unless (length($value) >= $directive) {

            my $handle = $field->{label} || $field->{name};
            my $characters = int($directive) > 1 ? "characters" : "character";

            my $error =
              "$handle must contain at-least " . "$directive $characters";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_min_sum {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        unless ($value >= $directive) {

            my $handle = $field->{label} || $field->{name};
            my $error = "$handle can't be less than " . "$directive";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_min_symbols {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        my @i = ($value =~ /[^0-9a-zA-Z]/g);

        unless (@i >= $directive) {

            my $handle = $field->{label} || $field->{name};
            my $characters = int($directive) > 1 ? "symbols" : "symbol";

            my $error =
              "$handle must contain at-least " . "$directive $characters";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_options {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        # build the regex
        my (@options) =
          "ARRAY" eq ref $directive
          ? @{$directive}
          : split /(?:\s{1,})?[,\-]{1,}(?:\s{1,})?/, $directive;

        unless (grep { $value =~ /^$_$/ } @options) {

            my $handle = $field->{label} || $field->{name};

            my $error =
                "$handle must be "
              . join(", ", (@options[(0 .. ($#options - 1))]))
              . " or $options[-1]";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}

sub configuration_validator_pattern {

    my ($directive, $value, $field, $class) = @_;

    if (defined $value) {

        # build the regex
        my $regex = $directive;

        unless ("Regexp" eq ref $regex) {

            $regex =~ s/([^#X ])/\\$1/g;
            $regex =~ s/#/\\d/g;
            $regex =~ s/X/[a-zA-Z]/g;
            $regex = qr/$regex/;

        }

        unless ($value =~ $regex) {

            my $handle = $field->{label} || $field->{name};

            my $error = "$handle does not match the " . "pattern $directive";

            $field->errors->add($field->{error} || $error);

            return 0;

        }

    }

    return 1;

}


sub error_count {

    my ($self) = @_;

    my $count = scalar($self->get_errors) || 0;

    return $count;

}


sub error_fields {

    my ($self, @fields) = @_;

    my $failed = {};

    @fields = $self->fields->keys unless @fields;

    foreach my $name (@fields) {

        my $field = $self->fields->{$name};

        if ($field->{errors}->count) {

            $failed->{$name} = $field->{errors}->list;

        }

    }

    return $failed;

}


sub errors_to_string {

    my ($self, $delimiter, $transformer) = @_;

    my $errors = Validation::Class::Errors->new([]);   # handle combined errors

    $errors->add($self->{errors}->all);

    $self->fields->each(
        sub {

            $errors->add($_[1]->{errors}->all);

        }
    );

    return $errors->to_string($delimiter, $transformer);

}


sub flatten_params {

    my ($self, $params) = @_;

    return undef unless "HASH" eq ref $params;

    my ($ad, $hd) = @{$self->hash_inflator}{'ArrayDelimiter', 'HashDelimiter'};

    my $serializer = Hash::Flatten->new($self->hash_inflator);

    return grep({ref $_} values %{$params})
      ?

      # do not flatten params if suspected to have already been flattened
      $serializer->flatten($params)
      : $params;

}


sub get_errors {

    my ($self, @criteria) = @_;

    my $errors = Validation::Class::Errors->new([]);   # handle combined errors

    if (!@criteria) {

        $errors->add($self->{errors}->all);

        $self->fields->each(
            sub {

                $errors->add($_[1]->{errors}->all);

            }
        );

    }

    elsif ("REGEXP" eq uc ref $criteria[0]) {

        my $query = $criteria[0];

        $errors->add($self->{errors}->find($query));

        $self->fields->each(
            sub {

                $errors->add($_[1]->{errors}->find($query));

            }
        );

    }

    else {

        for (@criteria) {

            $errors->add($self->fields->{$_}->{errors}->all);

        }

    }

    return ($errors->all);

}


sub get_fields {

    my ($self, @fields) = @_;

    my $fields = {};

    $self->fields->each(sub { $fields->{$_[0]} = $_[1] || {} });

    if (@fields) {

        return @fields ? (map { $fields->{$_} || undef } @fields) : ();

    }

    else {

        return $fields;

    }

}


sub get_params {

    my ($self, @params) = @_;

    my $params = $self->params->hash || {};

    $params = $self->unflatten_params($params);

    if (@params) {

        return @params ? (map { $params->{$_} || undef } @params) : ();

    }

    else {

        return $params;

    }

}


sub get_value {

    my ($self, $name) = @_;

    return undef unless $self->fields->has($name);

    my $field = $self->fields->{$name};

    my $value = undef;

    if (exists $self->params->{$name}) {

        $value = $self->params->{$name};

    }

    else {

        my $params = $self->get_params;    # unflattened params

        if (exists $params->{$name}) {

            $value = $params->{$name};

        }

    }

    unless (defined $value) {

        if (exists $field->{default}) {

            $value =
              "CODE" eq ref $field->{default}
              ? $field->{default}->($self)
              : $field->{default};

        }

    }

    return $value;

}

sub merge_field {

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

                if ("ARRAY" eq ref $field->{$key}) {

                    my @values = "ARRAY" eq ref $value ? @{$value} : ($value);

                    push @values, @{$field->{$key}};

                    @values = do {

                        my %uniq = ();

                        $uniq{$_} = $_ for @values;

                        values %uniq


                    };

                    $field->{$key} = [@values];

                }

                # simple copy

                else {

                    $field->{$key} = "ARRAY" eq ref $value ? $value : [$value];

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

sub merge_mixin {

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

                    my @values = "ARRAY" eq ref $value ? @{$value} : ($value);

                    push @values, @{$field->{$key}};

                    @values = do {

                        my %uniq = ();

                        $uniq{$_} = $_ for @values;

                        values %uniq

                    };

                    $field->{$key} = [@values];

                }

                # merge copy
                else {

                    my @values = "ARRAY" eq ref $value ? @{$value} : ($value);

                    push @values, $field->{$key} if $field->{$key};

                    @values = do {

                        my %uniq = ();

                        $uniq{$_} = $_ for @values;

                        values %uniq

                    };

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


sub normalize {

    my $self = shift;

    # reset fields
    # NOTICE: (called twice in this routine, not sure why, must
    # investigate further although it doesn't currently break anything)

    $self->reset_fields;

    # validate mixin directives

    while (my ($name, $mixin) = each(%{$self->mixins})) {

        $self->check_mixin($name, $mixin);

    }

    # validate field directives and create default directives if needed

    my $validate_field = sub {

        my ($name, $field) = @_;

        $self->check_field($name, $field);

        # by default fields should have a filters directive

        if (!defined $field->{filters}) {

            $field->{filters} = [];

        }

        # by default fields should have a filtering directive

        if (!defined $field->{filtering}) {

            $field->{filtering} = $self->filtering if $self->filtering;

        }

        # static labels and error messages may contain multiline
        # strings for the sake of aesthetics, flatten them here

        foreach my $string ('error', 'label') {

            if (defined $field->{$string}) {

                $field->{$string} =~ s/^[\n\s\t\r]+//g;
                $field->{$string} =~ s/[\n\s\t\r]+$//g;
                $field->{$string} =~ s/[\n\s\t\r]+/ /g;

            }

        }

        # respect readonly fields

        if (defined $field->{readonly}) {

            delete $self->params->{$name} if exists $self->params->{$name};

        }

    };

    $self->fields->each($validate_field);

    # check for and process a mixin directive

    my $process_mixins = sub {

        my ($name, $field) = @_;

        $self->apply_mixin($name, $field->{mixin}) if $field->{mixin};

    };

    $self->fields->each($process_mixins);

    # check for and process a mixin_field directive

    my $process_mixin_fields = sub {

        my ($name, $field) = @_;

        if ($field->{mixin_field}) {

            $self->apply_mixin_field($field->{mixin_field}, $name)
              if $self->fields->{$field->{mixin_field}};

        }

    };

    $self->fields->each($process_mixin_fields);

    # alias checking, ... for duplicate aliases, etc

    my $fieldtree = {};
    my $aliastree = {};

    my $find_duplicates = sub {

        my ($name, $field) = @_;

        $fieldtree->{$name} = $name;    # just a counter

        if (defined $field->{alias}) {

            my $aliases =
              "ARRAY" eq ref $field->{alias}
              ? $field->{alias}
              : [$field->{alias}];

            foreach my $alias (@{$aliases}) {

                if ($aliastree->{$alias}) {

                    my $error = qq(
                        The field $field contains the alias $alias which is
                        also defined in the field $aliastree->{$alias}
                    );

                    $self->throw_error($error);

                }
                elsif ($fieldtree->{$alias}) {

                    my $error = qq(
                        The field $field contains the alias $alias which is 
                        the name of an existing field
                    );

                    $self->throw_error($error);

                }
                else {

                    $aliastree->{$alias} = $field;

                }

            }

        }

    };

    $self->fields->each($find_duplicates);

    # restore order to the land

    $self->reset_fields;

    return $self;

}


sub param {

    my ($self, $name, $value) = @_;

    if ($name && !ref($name)) {

        if (defined $value) {

            $self->set_params($name => $value);

            return $value;

        }

        if ($self->params->has($name)) {

            return $self->params->{$name};

        }

    }

    return undef;

}

sub pitch_error {

    my ($self, $error_message) = @_;

    $error_message =~ s/\n/ /g;
    $error_message =~ s/\s+/ /g;

    if ($self->ignore_unknown) {

        if ($self->report_unknown) {

            $self->errors->add($error_message);

        }

    }

    else {

        $self->throw_error($error_message);

    }

}


sub plugin {

    my ($self, $class) = @_;

    return 0 unless $class;

    # transform what looks like a shortname

    if ($class !~ /::/) {

        my @parts = split /[^0-9A-Za-z_]/, $class;

        foreach my $part (@parts) {

            $part = ucfirst $part;
            $part =~ s/([a-z])_([a-z])/$1\u$2/g;

        }

        if (!$parts[0]) {

            shift @parts;

            $class = join "::", @parts;

        }

        else {

            my @rootspaces = (

                $self->{package},
                'Validation::Class::Plugin'

            );

            my $matched = 0;

            foreach my $rootspace (@rootspaces) {

                $class = join "::", $rootspace, @parts;

                eval '$matched = $class->can("new") ? 1 : 0';

                last if $matched;

            }

        }

    }

    return $self->plugins->{$class};

}

sub proxy_attributes {

    return qw{

      fields
      filtering
      hash_inflator
      ignore_failure
      ignore_unknown
      params
      report_failure
      report_unknown
      stash

      }

}

sub proxy_methods {

    return qw{

      class
      clear_queue
      error
      error_count
      error_fields
      errors
      errors_to_string
      get_errors
      get_fields
      get_params
      fields
      filtering
      hash_inflator
      ignore_failure
      ignore_unknown
      param
      params
      plugin
      queue
      report_failure
      report_unknown
      reset_errors
      reset_fields
      reset_params
      set_errors
      set_fields
      set_params
      stash

      }

}

sub proxy_methods_wrapped {

    return qw{

      set_method
      validate
      validate_profile

      }

}


sub queue {

    my $self = shift;

    push @{$self->queued}, @_;

    return $self;

}


sub reset {

    my $self = shift;

    $self->queued([]);

    $self->reset_fields;

    return $self;

}


sub reset_errors {

    my $self = shift;

    $self->errors->clear;

    foreach my $field ($self->fields->values) {

        $field->{errors}->clear;

    }

    return $self;

}


sub reset_fields {

    my $self = shift;

    foreach my $field ($self->fields->keys) {

        # set default, special directives, etc
        $self->fields->{$field}->{name} = $field;
        $self->fields->{$field}->{':toggle'} = undef;

        delete $self->fields->{$field}->{value};

    }

    $self->reset_errors();

    return $self;

}


sub reset_params {

    my $self = shift;

    my $params = @_ % 2 ? $_[0] : {@_};

    $self->params->clear;

    $self->params->add($params);

    return $self;

}


sub set_errors {

    my ($self, @errors) = @_;

    $self->errors->add(@errors) if @errors;

    return $self->errors->count;

}


sub set_fields {

    my $self = shift;

    my $fields = @_ % 2 ? $_[0] : {@_};

    $self->fields->add($fields);

    return $self;

}


sub set_method {

    my ($self, $context, $name, $code) = @_;

    confess "Context object ($self->{package} class instance) required "
      . "to perform validation"
      unless $self->{package} eq ref $context;

    my $class = ref $context;

    my $shortname = $name;
    $shortname =~ s/::/\_/g;
    $shortname =~ s/[^a-zA-Z0-9\_]/\_/g;
    $shortname =~ s/([a-z])([A-Z])/$1\_$2/g;
    $shortname = lc $shortname;

    $self->throw_error(
        "Error creating method $shortname, method already exists")
      if $class->can($shortname);

    # place code on the calling class

    no strict 'refs';

    *{"${class}::$shortname"} = $code;

}


sub set_params {

    my $self = shift;

    my $args = @_ % 2 ? $_[0] : {@_};

    my $params = $self->get_params;    # unflattened params

    while (my ($k, $v) = each(%{$args})) {

        $params->{$k} = $v;            # add new/overwrite existing

    }

    $params = $self->flatten_params($params);

    $self->params->clear;

    $self->params->add($params);

    return $self;

}


sub set_value {

    my ($self, $name, $value) = @_;

    if (!$self->fields->has($name)) {

        $self->pitch_error("Field $name does not exist");

    }

    else {

        my $error = qq{
            "Field value for $name must be a scalar value or arrayref"
        };

        $self->throw_error($error)
          if ref($value) && "ARRAY" ne ref $value;

        unless (defined $self->fields->{$name}->{readonly}) {

            my $params = $self->unflatten_params($self->params->hash);

            $params->{$name} = $value;

            $self->set_params($name => $value);

        }

    }

    return $self;

}


sub stash {

    my ($self, @requests) = @_;

    if (@requests) {

        if (@requests == 1) {

            my $request = $requests[0];

            if ("HASH" eq ref $request) {

                @requests = %{$request};

            }
            else {

                return $self->stashed->{$request};

            }

        }

        if (@requests > 1) {

            my %data = @requests;

            while (my ($key, $value) = each %data) {

                $self->stashed->{$key} = $value;

            }

        }

    }

    return $self->stashed;

}

sub throw_error {

    my $error_message = pop;

    $error_message =~ s/\n/ /g;
    $error_message =~ s/\s+/ /g;

    confess $error_message ;

}


sub unflatten_params {

    my ($self, $params) = @_;

    return undef unless "HASH" eq ref $params;

    my $serializer = Hash::Flatten->new($self->hash_inflator);

    return $serializer->unflatten($params) || {};

}


sub validate {

    my ($self, $context, @fields) = @_;

    confess "Context object ($self->{package} class instance) required "
      . "to perform validation"
      unless $self->{package} eq ref $context;

    # first-things-first, normalize our environment

    $self->normalize();

    # include fields queued by the queue method

    if (@{$self->queued}) {

        push @fields, @{$self->queued};

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

            # set field toggle directive

            $field =~ s/^[\-\+]{1}//;

            $self->fields->{$field}->{':toggle'} = $switch
              if $self->fields->has($field);

        }

    }

    # create alias map manually if requested
    # extremely-deprecated but it remains for back-compat and nostalgia !!!

    my $alias_map;

    if ("HASH" eq ref $fields[0]) {

        $alias_map = $fields[0];
        @fields    = ();           # blank

        while (my ($name, $alias) = each(%{$alias_map})) {

            $self->set_params($alias => delete $self->params->{$name});
            push @fields, $alias;

        }

    }

    # create a map from aliases if applicable

    my $alias_mapping = sub {

        my ($name, $field) = @_;

        if (defined $field->{alias}) {

            my $aliases =
              "ARRAY" eq ref $field->{alias}
              ? $field->{alias}
              : [$field->{alias}];

            foreach my $alias (@{$aliases}) {

                if (defined $self->params->{$alias}) {

                    $self->set_params($name => delete $self->params->{$alias});
                    push @fields, $name;

                }

            }

        }

    };

    $self->fields->each($alias_mapping);

    my @clones = ();

    # begin validation !!!

    if ($self->params->count) {

        # check if any parameters are arrayrefs
        # and handle them appropriately (clone, validate, then reap)

        my ($ad, $hd) = @{$self->hash_inflator}{

            # ^^ pun here
            'ArrayDelimiter', 'HashDelimiter'
          };

        my %seen = ();

        my $create_clones_routine = sub {

            my ($key, $value) = @_;

            my $name = $1 if $key =~ /(.*)$ad\d+$/;

            if (defined $name) {

                unless ($seen{$name}) {

                    my $field = $self->fields->{$name};

                    if ($field) {

                        $seen{$name}++;

                        my $varcount =
                          scalar grep {/$name$ad\d+$/} $self->params->keys;

                        for (my $i = 0; $i < $varcount; $i++) {

                            unless (defined $self->fields->{"$name:$i"}) {

                                my $label =
                                  ($field->{label} || $field->{name});

                                $self->clone($name, "$name:$i",
                                    {label => $label . " #" . ($i + 1)});

                                push @clones, "$name:$i";  # to be reaped later
                                push @fields, "$name:$i"   # black hackery
                                  if @fields && grep { $_ eq $name } @fields;

                            }

                        }

                        # like it never existed ...
                        # remove clone subject from the fields list

                        @fields = grep { $_ ne $name } @fields
                          if @fields;                      # ...

                    }

                }

            }

        };

        $self->params->each($create_clones_routine);

        # run pre-filtering if filtering is enabled

        $self->apply_filters('pre') if $self->filtering;

        if (@fields) {

            # validate all parameters against only the fields explicitly
            # requested to be validated

            $self->validate_params_specified($context, @fields);

        }

        else {

         # validate all parameters against all defined fields because no fields
         # were explicitly requested to be validated - i.e. not explicitly
         # defining fields to be validated effectively allows the parameters
         # submitted to dictate what gets validated (may not be ideal)

            $self->validate_params_discovered($context);

        }

    }

    else {

        if (@fields) {

            # validate fields specified although no parameters were submitted
            # will likely pass validation unless fields exist with
            # a *required* directive or other validation logic
            # expecting a value

            $self->validate_fields_specified($context, @fields);

        }

        else {

            # validate all defined fields although no parameters were submitted
            # will likely pass validation unless fields exist with
            # a *required* directive or other validation logic
            # expecting a value

            $self->validate_fields_discovered($context);

        }

    }

    my $valid = $self->error_count ? 0 : 1;

    # restore parameters from deprecated alias map functionality

    if (defined $alias_map) {

        # reversal
        while (my ($name, $alias) = each(%{$alias_map})) {

            $self->set_params($name => delete $self->params->{$alias});

        }

    }

    # reap cloned fields

    foreach my $clone (@clones) {

        my ($name, $index) = split /:/, $clone;

        if ($self->fields->has($name)) {

            my $field = $self->fields->get($name);
            my $clone = $self->fields->get($clone);

            $field->errors->add($clone->errors->all);

        }

        $self->fields->remove($clone);

    }

    # run post-validation filtering

    $self->apply_filters('post') if $self->filtering && $valid;

    return $valid;    # returns true if no errors

}

sub validate_fields_discovered {

    my ($self, $context) = @_;

    my @fields = sort $self->fields->keys;

    if (@fields) {

        $self->validate_fields_specified($context, @fields);

    }

    else {

        # if no parameters (or) fields are found ... you're screwed :)
        # instead of dying, warn and continue, depending on configuration

        my $error = qq{
            No parameters were submitted and no fields are 
            registered. Fields and parameters are required 
            for validation
        };

        if ($self->ignore_unknown) {

            if ($self->report_unknown) {

                $self->errors->add($error);

            }

        }

        else {

            $self->throw_error($error);

        }

    }

}

sub validate_fields_specified {

    my ($self, $context, @fields) = @_;

    foreach my $field_name (@fields) {

        if (!defined $self->fields->{$field_name}) {

            $self->pitch_error(
                "Data validation field $field_name does not exist");
            next;

        }

        my $field = $self->fields->{$field_name};

        $field->{name}  = $field_name;
        $field->{value} = $self->get_value($field_name);

        my @args = ($context, $field, $self->params);

        # execute simple validation

        $self->apply_validator($field_name, $field);

        # custom validation

        if (defined $field->{validation} && $field->{value}) {

            my $count  = $field->errors->count;
            my $result = $field->validation->(@args);

            if (!$result || $field->errors->count > $count) {

                # assuming the validation routine failed or issued an error

                if (defined $field->{error}) {

                    $field->{errors}->add($field->{error});

                }

                else {

                    my $error_msg = join " ",

                      ($field->{label} || $field->{name}),
                      "could not be validated";

                    $field->errors->add($error_msg)
                      unless $field->errors->count > $count;

                }

            }

        }

    }

}

sub validate_params_discovered {

    my ($self, $context) = @_;

    # process all params

    my $validate_param = sub {

        my ($name, $param) = @_;

        if (!$self->fields->has($name)) {

            $self->pitch_error("Data validation field $name does not exist");

        }

        else {

            my $field = $self->fields->{$name};

            $field->{name}  = $name;
            $field->{value} = $self->get_value($name);

            # create arguments to be passed to the validation directive

            my @args = ($context, $field, $self->params);

            # execute validator directives

            $self->apply_validator($name, $field);

            # execute custom/validation directive

            if (defined $field->{validation} && $field->{value}) {

                my $count  = $field->errors->count;
                my $result = $field->validation->(@args);

                if (!$result || $field->errors->count > $count) {

                    # assuming the validation routine failed or issued an error

                    if (defined $field->{error}) {

                        $field->{errors}->add($field->{error});

                    }

                    else {

                        my $error_msg = join " ",

                          ($field->{label} || $field->{name}),
                          "could not be validated";

                        $field->errors->add($error_msg)
                          unless $field->errors->count > $count;

                    }

                }

            }

        }

    };

    $self->params->each($validate_param);

}

sub validate_params_specified {

    my ($self, $context, @fields) = @_;

    foreach my $field_name (@fields) {

        if (!defined $self->fields->{$field_name}) {

            $self->pitch_error(
                "Data validation field $field_name does not exist");
            next;

        }

        my $field = $self->fields->{$field_name};

        $field->{name}  = $field_name;
        $field->{value} = $self->get_value($field_name);

        my @args = ($context, $field, $self->params);

        # execute simple validation

        $self->apply_validator($field_name, $field);

        # custom validation

        if (defined $field->{validation} && $field->{value}) {

            my $count  = $field->errors->count;
            my $result = $field->validation->(@args);

            if (!$result || $field->errors->count > $count) {

                # assuming the validation routine failed or issued an error

                if (defined $field->{error}) {

                    $field->{errors}->add($field->{error});

                }

                else {

                    my $error_msg = join " ",

                      ($field->{label} || $field->{name}),
                      "could not be validated";

                    $field->errors->add($error_msg)
                      unless $field->errors->count > $count;

                }

            }

        }

    }

}


sub validate_profile {

    my ($self, $context, $name, @args) = @_;

    confess "Context object ($self->{package} class instance) required "
      . "to perform validation"
      unless $self->{package} eq ref $context;

    return 0 unless $name;

    $self->normalize();
    $self->apply_filters('pre') if $self->filtering;

    if ("CODE" eq ref $self->profiles->{$name}) {

        return $self->profiles->{$name}->($context, @args)

    }

    return 0;

}

1;

__END__

=pod

=head1 NAME

Validation::Class::Prototype - Prototype and Data Validation Engine for Validation::Class

=head1 VERSION

version 7.72

=head1 SYNOPSIS

    package MyApp::User;
    
    use Validation::Class;
    
    # import other class config, etc
    
    set {
        # ...
    };
    
    # a mixin template
    
    mxn 'basic'  => {
        required   => 1
    };
    
    # a validation rule
    
    fld 'login'  => {
        label      => 'User Login',
        error      => 'Login invalid.',
        mixin      => 'basic',
        
        validation => sub {
        
            my ($self, $this_field, $all_params) = @_;
        
            return $this_field->value eq 'admin' ? 1 : 0;
        
        }
        
    };
    
    # a validation rule
    
    fld 'password'  => {
        label         => 'User Password',
        error         => 'Password invalid.',
        mixin         => 'basic',
        
        validation    => sub {
        
            my ($self, $this_field, $all_params) = @_;
        
            return $this_field->value eq 'pass' ? 1 : 0;
        
        }
        
    };
    
    # a validation profile
    
    pro 'registration'  => sub {
        
        my ($self, @args) = @_;
        
        return $self->validate(qw(+name +email -login +password))
        
    };
    
    # an auto-validating method
    
    mth 'register'  => {
        
        input => 'registration',
        using => sub {
            
            my ($self, @args) = shift;
            
            # ... do something
            
        }
        
    };
    
    1;

=head1 DESCRIPTION

Validation::Class::Prototype provides the data validation schema and routines
for all Validation::Class based classes. This class inherits from
L<Validation::Class::Base>. 

=head1 ATTRIBUTES

=head2 directives

The directives attribute returns a hashref of all defined directives.

    my $directives = $self->directives();
    ...

=head2 errors

The errors attribute provides error handling functionality and CANNOT be
overridden. This attribute is a L<Validation::Class::Errors> object.

    my $errors = $self->errors();
    ...

=head2 fields

The fields attribute provides field handling functionality and CANNOT be
overridden. This attribute is a L<Validation::Class::Fields> object.

    my $fields = $self->fields();
    ...

=head2 filtering

The filtering attribute (by default set to 'pre') controls when incoming data
is filtered. Setting this attribute to 'post' will defer filtering until after
validation occurs which allows any errors messages to report errors based on the
unaltered data. Alternatively, setting the filtering attribute to '' or undef
will bypass all filtering unless explicitly defined at the field-level.

    my $filtering = $self->filtering('post');
    
    $self->validate();
    ...

=head2 filters

The filters attribute returns a hashref of pre-defined filter definitions.

    my $filters = $self->filters();
    ...

=head2 hash_inflator

The hash_inflator attribute determines how the hash serializer (inflation/deflation)
behaves. The value must be a hashref of L<Hash::Flatten/OPTIONS> options. Purely
for the sake of consistency, you can use lowercase keys (with underscores) which
will be converted to camel-cased keys before passed to the serializer.

    my $self = MyApp::Validation->new(hash_inflator => {
        hash_delimiter => '/',
        array_delimiter => '//'
    });
    
    ...
    
    # then, hereinafter referred to as 
    
    $self->hash_inflator->{HashDelimiter} = '/';
    $self->hash_inflator->{ArrayDelimiter} = '//';

=head2 ignore_failure

The ignore_failure boolean determines whether your application will live or die
upon failing to validate a self-validating method defined using the method
keyword. This is on (1) by default, method validation failures will set errors
and can be determined by checking the error stack using one of the error message
methods. If turned off, the application will die and confess on failure.

    my $ignoring = $self->ignore_failure(1);
    ...

=head2 ignore_unknown

The ignore_unknown boolean determines whether your application will live or die
upon encountering unregistered field directives during validation. This is off
(0) by default, attempts to validate unknown fields WILL cause the program to die.

    my $ignoring = $self->ignore_unknown(1);
    ...

=head2 methods

The methods attribute returns a hashref of self-validating method definitions.

    my $methods = $self->methods(); # definitions are hashrefs
    ...

=head2 mixins

The mixins attribute returns a hashref of defined validation templates.

    my $mixins = $self->mixins();
    ...

=head2 params

The params attribute provides parameter handling functionality and CANNOT be
overridden. This attribute is a L<Validation::Class::Params> object.

    my $params = $self->params();
    ...

=head2 plugins

The plugins attribute returns a hashref of loaded plugins.

    my $plugins = $self->plugins();
    ...

=head2 profiles

The profiles attribute returns a hashref of validation profiles.

    my $profiles = $self->profiles();
    ...

=head2 queued

The queued attribute returns an arrayref of field names for (auto) validation.
It represents a list of field names stored to be used in validation later. If
the queued attribute contains a list, you can omit arguments to the validate
method. 

    my $queued = $self->queued([qw/.../]);
    ...

=head2 relatives

The relatives attribute returns a hashref of short-name/class-name pairs of
loaded child classes.

    my $relatives = $self->relatives();
    ...

=head2 report_failure

The report_failure boolean determines whether your application will report
self-validating method failures as class-level errors. This is off (0) by default,
if turned on, an error messages will be generated and set at the class-level
specifying the method which failed in addition to the existing messages.

    my $reporting = $self->report_failure(0);
    ...

=head2 report_unknown

The report_unknown boolean determines whether your application will report
unregistered fields as class-level errors upon encountering unregistered field
directives during validation. This is off (0) by default, attempts to validate
unknown fields will NOT be registered as class-level variables.

    my $reporting = $self->report_unknown(1);
    ...

=head1 METHODS

=head2 apply_filters

The apply_filters method (usually called automatically based on the filtering
attribute) can be used to run the currently defined parameters through the
filters defined in their matching fields.

    $self = $self->apply_filters;
    
    # apply filters to fields labeled as "don't filter automatically" (post)
    $self = $self->apply_filters('post'); 

=head2 class

The class method returns a new initialize validation class related to the
namespace of the calling class, the relative class would've been loaded via the
"load" keyword.

Existing parameters and configuration options are passed to the relative class'
constructor (including the stash). All attributes can be easily overwritten using
the attribute's accessors on the relative class.

Also, you may prevent/override arguments from being copied to the new class
object by supplying the them as arguments to this method.

The class method is also quite handy in that it will detect parameters that are
prefixed with the name of the class being fetched, and adjust the matching rule
(if any) to allow validation to occur.

    package Class;
    
    use Validation::Class;
    
    load classes => 1; # load child classes e.g. Class::*
    
    package main;
    
    my $input = Class->new(params => $params);
    
    my $child1  = $input->class('Child');      # loads Class::Child;
    my $child2  = $input->class('StepChild');  # loads Class::StepChild;
    
    my $child3  = $input->class('child');      # loads Class::Child;
    my $child4  = $input->class('step_child'); # loads Class::StepChild;
    
    # use any non-alphanumeric character or underscore as the namespace delimiter
    
    my $child5  = $input->class('step/child'); # loads Class::Step::Child;
    my $child5a = $input->class('step:child'); # loads Class::Step::Child;
    my $child5b = $input->class('step.child'); # loads Class::Step::Child;
    my $child5c = $input->class('step-child'); # loads Class::Step::Child;
    
    my $child6  = $input->class('CHILD');      # loads Class::CHILD;
    
    # intelligently detecting and map params to child class
    
    my $params = {
    
        'my.name'    => 'Guy Friday',
        'child.name' => 'Guy Friday Jr.'
    
    };
    
    $input->class('child'); # child field *name* mapped to param *child.name*
    
    # without copying params from class
    
    my $child = $input->class('child', params => {});
    
    # alternate syntax
    
    my $child = $input->class(-name => 'child', params => {});
    
    1;

=head2 clear_queue

The clear_queue method resets the queue container, see the queue method for more
information on queuing fields to be validated. The clear_queue method has yet
another useful behavior in that it can assign the values of the queued
parameters to the list it is passed, where the values are assigned in the same
order queued.

    my $self = Class->new(params => $params);
    
    $self->queue(qw(name +email));
    
    ...
    
    $self->queue(qw(+login +password));
    
    if ($self->validate) {
        
        $self->clear_queue(my($name, $email));
        
        print "Name is $name";
        
    }

=head2 clone

The clone method is used to create new fields (rules) from existing fields
on-the-fly. This is useful when you have a variable number of parameters being
validated that can share existing validation rules.

    package Class;
    
    use Validation::Class;
    
    field 'phone' => {
        label => 'Your Phone',
        required => 1
    };
    
    package main;
    
    my $self = Class->new(params => $params);
    
    # clone phone rule at run-time to validate dynamically created parameters
    $self->clone('phone', 'phone2', { label => 'Other Phone', required => 0 });
    $self->clone('phone', 'phone3', { label => 'Third Phone', required => 0 });
    $self->clone('phone', 'phone4', { label => 'Forth Phone', required => 0 });
    
    $self->validate(qw/phone phone2 phone3 phone4/);
    
    1;

=head2 error_count

The error_count method returns the total number of errors set at both the class
and field level.

    my $count = $self->error_count;

=head2 error_fields

The error_fields method returns a hashref containing the names of fields which
failed validation and an arrayref of error messages.

    unless ($self->validate) {
        
        my $failed = $self->error_fields;
        
    }
    
    my $suspects = $self->error_fields('field2', 'field3');

=head2 errors_to_string

The errors_to_string method stringifies the all error objects on both the class
and fields using the specified delimiter (defaulting to comma-space (", ")).

    return $self->errors_to_string("\n");
    return $self->errors_to_string(undef, sub{ ucfirst lc shift });
    
    unless ($self->validate) {
    
        return $self->errors_to_string;
    
    }

=head2 flatten_params

The flatten_params method accepts a single hashref and will return the
serialized version based on the the default or custom configuration of the hash
serializer L<Hash::Flatten> as configured via the hash_inflator() attribute.

    my $params = {
        
        user => {
            login => 'member',
            password => 'abc123456'
        }
        
    };
    
    my $serialized_params = $self->flatten_params($params);

=head2 get_errors

The get_errors method returns a list of combined class-and-field-level errors.

    my @errors = $self->get_errors; # returns list
    
    my @critical = $self->get_errors(qr/^critical:/i); # filter errors
    
    my @specific_field_errors = $self->get_errors('field_a', 'field_b');

=head2 get_fields

The get_fields method returns the list of references to the specified fields.
Returns undef if no arguments are passed. This method is likely to be used more
internally than externally.

    my ($this, $that) = $self->get_fields('this', 'that');

=head2 get_params

The get_params method returns the values of the parameters specified (as a list,
in the order specified). This method will return a list of key/value pairs if
no parameter names are passed. Note, this method always returns
exploded/unflattened parameters.

    if ($self->validate) {
    
        my ($name) = $self->get_params('name');
    
        my ($name, $email, $login, $password) =
            $self->get_params(qw/name email login password/);
        
        # you should note that if the params don't exist they will return undef
        # ... meaning you should check that it is defined before doing any
        # comparison checking -- as doing so would generate an error
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
    
    # alternatively ...
    
    my $params = $self->get_params; # return hashref of parameters
    
    print $params->{name};

=head2 get_value

The get_value method returns the absolute value (hardcoded, default or
parameter specified) for a given field. This method executes specific logic
which returns the value a field has based on a set of internal conditions. This
method otherwise returns undefined.

    my $value = $self->get_value('field_name');

=head2 normalize

The normalize method executes a set of routines that reset the parameter
environment filtering any parameters present. This method is executed
automatically at instantiation and again just before each validation event. 

    $self->normalize();

=head2 param

The param method gets/sets a single parameter by name. This method returns the
value assigned or undefined if the parameter does not exist.

    my $value = $self->param('name');
    
    $self->param($name => $value);

=head2 plugin

The plugin method returns the instantiated plugin object attached to the current
class.

    package Class;
    
    use Validation::Class;
    
    load plugin => ['TelephoneFormat'];
    load plugin => ['+Class::Plugin::Form::Elements'];
    
    package main;
    
    my $input = Class->new(params => $params);
    
    # get object for Validation::Class::Plugin::TelephoneFormat;
    
    my $plugin = $input->plugin('telephone_format');
    
    # use any non-alphanumeric character or underscore as the namespace delimiter
    # get object for Class::Plugin::Form::Elements;
    # note the leading character/delimiter
    
    # automatically resolves to the first matching namespace for $self
    # or Validation::Class::Plugin 
    
    my $plugin = $input->plugin('plugin:form:elements');
    
    # prefix with a special character to denote a fully-qualified namespace
    
    my $plugin = $input->plugin('+class:plugin:form:elements'); 
    
    # same as $input->proto->plugins->{'Class::Plugin::Form::Elements'};
    
    my $plugin = $input->plugin('Class::Plugin::Form::Elements');

=head2 queue

The queue method is a convenience method used specifically to append the
queued attribute allowing you to *queue* fields to be validated. This method
also allows you to set fields that must always be validated. 

    $self->queue(qw/name login/);
    $self->queue(qw/email_confirm/) if $input->param('chg_email');
    $self->queue(qw/password_confirm/) if $input->param('chg_pass');

=head2 reset

The reset method clears all errors, fields and queued field names, both at the
class and individual field levels.

    $self->reset();

=head2 reset_errors

The reset_errors method clears all errors, both at the class and individual
field levels. This method is called automatically every time the validate()
method is triggered.

    $self->reset_errors();

=head2 reset_fields

The reset_fields method clears all errors and field values, both at the class
and individual field levels. This method is executed automatically at
instantiation.

    $self->reset_fields();

=head2 reset_params

The reset_params method is responsible for completely removing any existing
parameters and adding those specified. This method returns the class object.
This method takes a list of key/value pairs or a single hashref.

    $self = $self->reset_params($new_params); # accepts list also

=head2 set_errors

The set_errors method pushes its arguments (error messages) onto the class-level
error stack and returns a count of class-level errors.

    my $count = $self->set_errors(..., ...);

=head2 set_fields

The set_fields method is responsible setting/overriding registered fields.
This method returns the class object. This method takes a list of key/value
pairs or a single hashref whose key should be a valid field name and whose
value should be a hashref that is a valid field configuration object.

    $self = $self->set_fields($name => $config); # accepts hashref also

=head2 set_method

The set_method method conveniently creates a method on the calling class, this
method is primarily intended to be used during instantiation of a plugin during
instantiation of the validation class.

    my $sub = $self->set_method(do_something => sub { ... });

Additionally, method names are flattened, e.g. ThisFunction will be converted to
this_function for convenience and consistency.

=head2 set_params

The set_params method is responsible for setting/replacing parameters while
ensuring that previously serialized parameters are taken into account. This
method returns the class object. This method takes a list of key/value pairs or
a single hashref whose key should match a field's name and whose value should
be a scalar or arrayref.

    $self = $self->set_params($name => $value); # accepts hashref also

=head2 set_value

The set_value method assigns a value to the specified field's parameter 
unless the field is readonly.

    $self = $self->set_value($name => $value);

=head2 stash

The stash method provides a container for context/instance specific information.
The stash is particularly useful when custom validation routines require insight
into context/instance specific operations.

    package MyApp::Validation;
    
    use Validation::Class;
    
    fld 'email' => {
        
        validation => sub {
            
            my ($self) = @_;
            
            my $db = $self->stash('database');
            
            return $db->find(...) ? 0 : 1 ; # email exists
            
        }
        
    };
    
    package main;
    
    $self->stash( { database => $dbix_object } );
    $self->stash( database => $dbix_object );
    
    ...

=head2 unflatten_params

The unflatten_params method accepts a single *flat* hashref and will return the
expanded version based on the the default or custom configuration of the hash
serializer L<Hash::Flatten> as configured via the hash_inflator() attribute.

    my $params = {
        'user.login' => 'member',
        'user.password' => 'abc123456'
    };
    
    $params = $self->unflatten_params($params);
        
    print $params->{user}->{login};

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
alter whether a field is required or not during run-time. This functionality is
often referred to as the *toggle* function.

This method is important when you define a field (or two or three) as required
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

=head2 validate_profile

The validate_profile method executes a stored validation profile, it requires a
profile name and can be passed additional parameters which get forwarded into the
profile routine in the order received.

    unless ($self->validate_profile('password_change')) {
    
        print $self->errors_to_string;
        
    }
    
    unless ($self->validate_profile('email_change', $dbi_handle)) {
        
        print $self->errors_to_string;
        
    }

=head1 DIRECTIVES

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
important keyword functions are field() and mixin(), which are used to declare
their respective properties. A mixin() declares a validation template where
its properties are intended to be copied within field() declarations which
declares validation rules, filters and other properties.

Both the field() and mixin() declarations/functions require two parameters, the
first being a name, used to identify the declaration and to be matched against
incoming input parameters and the second being a hashref of key/value pairs.
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
when a matching parameter is not present. Optionally, the default directive
can be a coderef allowing the default value to be set on request.

    # the default directive
    field 'quantity'  => {
        default => 1,
        ...
    };
    
    # the default directive as a coderef
    field 'quantity'  => {
        default => sub {
            return DB::Settings->default_quantity
        }
    };

=head2 error/errors

The error/errors directive is used to replace the system generated error
messages when a particular field doesn't validate. If a field fails multiple
directives, multiple errors will be generated for the same field. This may not
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
class to apply the field's filters at instantiation and before validation whereas
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

=head2 readonly

The readonly directive is used to symbolize a field whose parameter value should
not be honored and if encountered, deleted. Unlike the read-only attribute
options in other object systems, setting this will not cause you program to die
and in-fact, an experience programmer can selectively bypass this constraint.

    # the readonly directive
    field 'thename'  => {
        readonly => 1,
        ...
    };

=head2 value

The value directive is used internally to store the field's matching parameter's
value. This value can be set in the definition but SHOULD NOT BE used as a
default value unless you're sure no parameter will overwrite it during run-time.
If you need to set a default value, see the default directive.

    # the value directive
    field 'quantity'  => {
        value => 1,
        ...
    };

=head1 DIRECTIVES (FILTERS)

The filters directive is used to correct, alter and/or format the
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

=head2 alpha

The alpha filter removes all non-Alphabetic characters from the field's value.

    field 'foobar'  => {
        filters => 'alpha',
    };

=head2 alphanumeric

The alpha filter removes all non-Alphabetic and non-Numeric characters from the
field's value.

    field 'foobar'  => {
        filters => 'alphanumeric',
    };

=head2 capitalize

The capitalize filter attempts to capitalize the first word in each sentence,
where sentences are separated by a period and space, within the field's value.

    field 'foobar'  => {
        filters => 'capitalize',
    };

=head2 decimal

The decimal filter removes all non-decimal-based characters from the field's
value. Allows only: decimal, comma, and numbers.

    field 'foobar'  => {
        filters => 'decimal',
    };

=head2 lowercase

The lowercase filter converts the field's value to lowercase.

    field 'foobar'  => {
        filters => 'lowercase',
    };

=head2 numeric

The numeric filter removes all non-numeric characters from the field's
value.

    field 'foobar'  => {
        filters => 'numeric',
    };

=head2 strip

As with the trim filter the strip filter removes leading and trailing
whitespaces from the field's value and additionally removes multiple whitespaces
from between the values characters.

    field 'foobar'  => {
        filters => 'strip',
    };

=head2 titlecase

The titlecase filter converts the field's value to titlecase by capitalizing the
first letter of each word.

    field 'foobar'  => {
        filters => 'titlecase',
    };

=head2 trim

The trim filter removes leading and trailing whitespace from the field's value.

    field 'foobar'  => {
        filters => 'trim',
    };

=head2 uppercase

The uppercase filter converts the field's value to uppercase.

    field 'foobar'  => {
        filters => 'uppercase',
    };

=head1 DIRECTIVES (VALIDATORS)

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
is used to validate common use cases such as "checking the length of a parameter",
etc.

Please note that a directive's value can be either a scalar or arrayref, most
directives take a scalar value though some have the ability to take an arrayref
or parse a delimited list. There is no official documentation as to which
directives can accept lists of values although it will typically be evident.

    E.g. (a directive with a list of values)
    
    {
        directive => [qw(1 2 3)],
        directive => ['1', '2', '3'],
        directive => '1, 2, 3',
        directive => '1-2-3',
        directive => '1,2,3',
    }

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

=head2 required

The required directive is an important directive but can be misunderstood.
The required directive is used to ensure the submitted parameter exists and
has a value. If the parameter is never submitted, the directive is effectively
skipped. This directive can be thought of as the "must-have-a-value-if-exists"
directive.

    # the required directive
    field 'foobar'  => {
        required => 1,
        ...
    };
    
    # pass
    my $rules = MyApp::Validation->new(params => {   });
    $rules->validate(); #validate everything
    
    # fail
    my $rules = MyApp::Validation->new(params => { foobar => '' });
    $rules->validate(); #validate everything
    
    # fail
    my $rules = MyApp::Validation->new(params => {  });
    $rules->validate('foobar');
    
    # fail
    my $rules = MyApp::Validation->new(params => { foobar => '' });
    $rules->validate('foobar');
    
    # pass
    my $rules = MyApp::Validation->new(params => {  foobar => 'Nice' });
    $rules->validate('foobar');

See the toggle functionality within the validate() method. This method allows
you to temporarily alter whether a field is required or not.

=head2 validation

The validation directive is a coderef used add additional custom validation to
the field. The coderef must return true (to pass) or false (to fail). Custom
error messages can be set from within the coderef so make sure they are set
based on appropriate logic as the registration of error message are not
contingent on the success or failure of the routine. 

    # the validation directive
    field 'login'  => {
        
        validation => sub {
        
            my ($self, $this_field, $all_params) = @_;
        
            return 0 unless $this_field->value;
            return $this_field->value eq 'admin' ? 1 : 0;
        
        },
        
    };

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

