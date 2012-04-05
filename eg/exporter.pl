
BEGIN {

    use FindBin;
    use lib $FindBin::Bin . '/lib';
    use lib $FindBin::Bin . '/../lib';
    
}

package main;

use MyApp::Example;

my $eg = MyApp::Example->new;

my $ge = MyApp::Example->new;

$eg->{config}->{THING} = [1..9];

print $eg;
