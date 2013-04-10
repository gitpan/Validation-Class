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

    my $t = T->new(
        ignore_unknown => 1,
        report_unknown => 1,
    );

    $t->params->add(bar => 'usefulness');

    ok "T" eq ref $t, "T instantiated";

    ok $t->validate('bar'), 'request to validate bar, an alias of foo, validates successfully';
    ok ! $t->error_count, 't has no errors';
    ok ! $t->params->has('bar'), 't has no bar param';
    ok $t->params->has('foo'), 't has a foo param';
    ok 1 == @{$t->proto->stash->{'validation.fields'}} && $t->proto->stash->{'validation.fields'}->[0] eq 'foo', 't dynamically validated foo instead of bar as requested';

}

done_testing();
