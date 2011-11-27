use Test::More tests => 8;

# begin
package MyVal;

use Validation::Class;

field 'login',
  { label     => 'user login',
    error     => 'login invalid',
    filtering => 'post',
    filters   => [qw/trim strip alphanumeric/]
  };

field 'password', {
    label => 'user password',
    error => 'password invalid',

    # no filtering at all
};

field 'name',
  { label     => 'user name',
    error     => 'invalid name',
    filtering => 'pre',
    filters   => [qw/trim strip alpha titlecase/]
  };

package main;

my $rules = MyVal->new(
    params => {
        name     => 'george 3',
        login    => 'admin@abco.com',
        password => '#!/bin/bash',
    }
);

ok $rules, 'validation class init ok';
ok $rules->params->{name}     =~ /^George$/,           'name as expected';
ok $rules->params->{login}    =~ /^admin\@abco\.com$/, 'login as expected';
ok $rules->params->{password} =~ /^#!\/bin\/bash$/,    'password as expected';

ok $rules->validate, 'validation failed ok';

ok $rules->params->{name}     =~ /^George$/,        'name as expected';
ok $rules->params->{login}    =~ /^adminabcocom$/,  'login as expected';
ok $rules->params->{password} =~ /^#!\/bin\/bash$/, 'password as expected';


