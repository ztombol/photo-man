package TestsFor::TCO::Output::Columnar::Field;

use Test::Most;
use base 'TestsFor';
use TCO::Output::Columnar::Field;

sub class_to_test { 'TCO::Output::Columnar::Field' }

sub constructor : Tests {
    my $self  = shift;
    my $class = $self->class_to_test;

    can_ok $class, 'new';
    throws_ok { $class->new }
        qr/Attribute.*required/,
        "Creating a $class without proper attributes should fail";
    isa_ok $self->default_field, $class;
}

sub default_field {
    my $self = shift;
    return $self->class_to_test->new(
        type => 'test',
    )
}

1;
