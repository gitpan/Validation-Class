use Test::More tests => 5;

package MyVal;

use Validation::Class;

mixin ID => {
    required   => 1,
    min_length => 1,
    max_length => 11
};

mixin TEXT => {
    required   => 1,
    min_length => 1,
    max_length => 255,
    filters    => [qw/trim strip/]
};

mixin UTEXT => {
    required   => 1,
    min_length => 1,
    max_length => 255,
    filters    => 'uppercase'
};

field id => {
    mixin => 'ID',
    label => 'Object ID',
    error => 'Object ID error'
};

field name => {
    mixin   => 'TEXT',
    label   => 'Object Name',
    error   => 'Object Name error',
    filters => ['uppercase']
};

field handle => {
    mixin   => 'UTEXT',
    label   => 'Object Handle',
    error   => 'Object Handle error',
    filters => [qw/trim strip/]
};

field email => {
    mixin      => 'TEXT',
    label      => 'Object Email',
    error      => 'Object Email error',
    max_length => 500
};

field email_confirm => {
    mixin_field => 'email',
    label       => 'Object Email Confirm',
    error       => 'Object Email confirmation error',
    min_length  => 5
};

profile email_change => sub {

    my ($self, $hash) = @_;

    $self->validate('+email', '+email_confirm');

    return $self->error_count && keys %{$hash} ? 1 : 0;

};

package main;

my $v = MyVal->new(params => {});
ok $v, 'initialization successful';
ok !$v->validate_profile('email_change'),
  'email_change profile did not validate';
ok $v->error_count == 2, '2 errors encountered on failure';

$v->params->{email}         = 'abc';
$v->params->{email_confirm} = 'abc';
ok !$v->validate_profile('email_change'),
  'email_change profile did not validate';
ok $v->validate_profile('email_change', {this => 'that'}),
  'email_change profile validated OK';

