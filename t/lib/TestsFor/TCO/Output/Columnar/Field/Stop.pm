package TestsFor::TCO::Output::Columnar::Field::Stop;

use Test::Most;
use base 'TestsFor::TCO::Output::Columnar::Field';
use TCO::Output::Columnar::Field::Stop;

sub class_to_test { 'TCO::Output::Columnar::Field::Stop' }

sub constructor : Tests {
    my $self  = shift;
    my $class = $self->class_to_test;

    can_ok $class, 'new';
    throws_ok { $class->new({}) }
        qr/Error: constructor requires no parameters!/;
        "Creating a $class with attributes should fail";
    isa_ok $self->default_field, $class;
}

sub default_field {
    my $self = shift;
    return $self->class_to_test->new;
}

1;
