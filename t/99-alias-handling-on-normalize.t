use FindBin;
use Test::More;
use utf8;
use strict;
use warnings;

{

    use_ok 'Validation::Class';

}

{

    {
        package T;
        use Validation::Class;

        field foo => { required => 1, alias => ['bar'] };

    }

    package main;

    my $obj = sub {

        my $t = T->new(
            ignore_unknown => 1,
            report_unknown => 1,
        );

        $t->params->add(@_);

        ok "T" eq ref $t, "T instantiated";

        return $t;

    };

    my $t;

    $t = $obj->(bar => 'okiedokie');

    ok $t->validate, 't validates all params successfully';
    ok ! $t->error_count, 't has no errors';
    ok ! $t->params->has('bar'), 't has no bar param';
    ok $t->params->has('foo'), 't has a foo param';

    $t = $obj->(foo => 'ummmmmk', bar => 'okiedokie');

    ok ! $t->validate, 't CAN NOT validate params';

    ok 1 == $t->error_count, 't has one error';
    ok $t->errors_to_string =~ /multiple/, 't field foo not configured for multiple values';
    ok ! $t->params->has('bar'), 't has no bar param';
    ok $t->params->has('foo'), 't has a foo param';
    ok "ARRAY" eq ref $t->params->get('foo'), 't foo param contains an array';

}

done_testing();
