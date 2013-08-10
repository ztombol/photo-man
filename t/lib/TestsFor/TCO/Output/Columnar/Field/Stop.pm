package TestsFor::TCO::Output::Columnar::Field::Stop;

use Test::Class::Most
    parent      =>'TestsFor',
    attributes  => [qw(default_field)];

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

    # Instantiate default field object.
    $self->default_field(
        $class->new()
    );
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

sub constructor : Tests {
    my $self  = shift;
    my $class = $self->class_to_test;

    can_ok $class, 'new';
    throws_ok { $class->new({}) }
        qr/Error: constructor requires no parameters!/,
        "Creating a $class with attributes should fail";
    isa_ok $self->default_field, $class;
}

1;
