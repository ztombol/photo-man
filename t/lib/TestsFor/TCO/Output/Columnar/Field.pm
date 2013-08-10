package TestsFor::TCO::Output::Columnar::Field;

use Test::Class::Most
    parent      =>'TestsFor',
    attributes  => [qw(default_field)],
    is_abstract => 1;

sub is_abstract {
    my $self = shift;
    return Test::Class::Most->is_abstract($self);
}

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
        $class->new(
            type => 'test',
        )
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

    return if $self->is_abstract;

    can_ok $class, 'new';
    throws_ok { $class->new }
        qr/Attribute.*required/,
        "Creating a $class without proper attributes should fail";
    isa_ok $self->default_field, $class;
}

1;
