package TestsFor;

use Test::Class::Most
    attributes => [qw(class_to_test)];

INIT {
    # Run all tests.
    Test::Class->runtests;
}

sub startup  : Tests(startup) {
    my $test  = shift;
    my $class = ref $test;
    $class =~ s/^TestsFor:://;

    # Automatically set 'class_to_test' and load the class.
    eval "use $class";
    die $@ if $@;
    $test->class_to_test($class);
}
sub setup    : Tests(setup)    {}
sub teardown : Tests(teardown) {}
sub shutdown : Tests(shutdown) {}

1;
