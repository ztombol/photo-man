package TestsFor::TCO::Output::Columnar::Field::Literal;

use Test::Class::Most
    parent      => 'TestsFor::TCO::Output::Columnar::Field';

sub startup : Tests(startup) {
    my $self  = shift;
    my $class = ref $self;

    # First call the parent method.
    $self->next::method;

    # Startup code goes here...
}

sub setup : Tests(setup) {
    my $self  = shift;
    my $class = $self->class_to_test;

    # First call the parent method.
    $self->next::method;

    # Setup code goes here...
}

sub teardown : Tests(teardown) {
    my $self = shift;

    # Teardown code goes here...

    # Finally, call parent method.
    $self->next::method;
}

sub shutdown : Tests(shutdown) {
    my $self = shift;

    # Shutdown code goes here...

    # Finally, call parent method.
    $self->next::method;
}

# Instantiates default field object.
sub create_default_field {
    my $self  = shift;
    my $class = $self->class_to_test;

    return $class->new(
        string => "It's okay, I'm a leaf on the wind.",
    );
}

sub as_string : Tests {
    my $self = shift;
    my $string = "Shiny. Let's be bad guys";

    my $field = $self->class_to_test->new({
        string => $string,
    });
    is $field->as_string($string), $string,
        'field should render the string correctly';
}

1;
