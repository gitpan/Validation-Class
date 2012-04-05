package MyApp::Class;

use Validation::Class;
use Validation::Class::Exporter;

Validation::Class::Exporter->apply_spec(
    routines => ['thing'],               # export routines as is
    settings => [base => __PACKAGE__]    # passed to Validation::Class::load()
);

has foo => 0;

bld sub {

    shift->foo(1);

};

sub thing {

    my $args = pop;

    my $class = shift || caller;

    $class->{config}->{THING} = [$args];

}

1;
