package TestsFor::TCO::Output::Columnar::Field::Literal;

use Test::Most;
use base 'TestsFor::TCO::Output::Columnar::Field';
use TCO::Output::Columnar::Field::Literal;

sub class_to_test { 'TCO::Output::Columnar::Field::Literal' }

sub as_string : Tests {
    my $self = shift;
    my $string = "Shiny. Let's be bad guys";

    my $field = $self->class_to_test->new({
        string => $string,
    });
    is $field->as_string($string), $string,
        'field should render the string correctly';
}

sub default_field {
    my $self = shift;
    return $self->class_to_test->new(
        string => "It's okay, I'm a leaf on the wind.",
    );
}

1;
