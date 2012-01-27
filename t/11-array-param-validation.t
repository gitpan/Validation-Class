use Test::More tests => 3;

package MyVal;

use Validation::Class;

package main;

my $v = MyVal->new(
    fields => {foobar => {min_length => 5}},
    params => {foobar => [join('', 1 .. 4), join('', 1 .. 5),]}
);

# check that an array parameters is handled properly on-the-fly
ok !$v->validate('foobar'), 'validation does not pass';
ok $v->error_count == 1,
  '1 errors set, 1 wrong element of the param array value';
ok $v->errors_to_string =~ /#/,
  'error message identifies the problem param array element';
