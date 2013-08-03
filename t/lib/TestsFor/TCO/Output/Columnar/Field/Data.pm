package TestsFor::TCO::Output::Columnar::Field::Data;

use Test::Most;
use base 'TestsFor::TCO::Output::Columnar::Field';
use TCO::Output::Columnar::Field::Data;

sub class_to_test { 'TCO::Output::Columnar::Field::Data' }

sub as_string : Tests {
    my $self = shift;

    $self->data_untruncated;
    $self->data_truncated;
    $self->data_user_truncator;
}

sub data_untruncated {
    my $self = shift;
    my $field;
    my $string = "Shiny!";

    # Left.
    $field = $self->class_to_test->new(
        width     => 20,
        alignment => 'left',
    );
    is $field->as_string($string), 'Shiny!              ',
        'untruncated, left aligned data should be rendered correctly';
    
    # Centre.
    $field = $self->class_to_test->new(
        width     => 20,
        alignment => 'centre',
    );
    is $field->as_string($string), '       Shiny!       ',
        'untruncated, centre aligned data should be rendered correctly';
    
    # Right.
    $field = $self->class_to_test->new(
        width     => 20,
        alignment => 'right',
    );
    is $field->as_string($string), '              Shiny!',
        'untruncates, right aligned data should be rendered correctly';
}

sub data_truncated {
    my $self = shift;
    my $field;
    my $string = "Did you see the chandelier? It's hovering.";
    
    # Left.
    $field = $self->class_to_test->new(
        width     => 20,
        alignment => 'left',
    );
    is $field->as_string($string), 'Did you see the c...',
        'truncated, left aligned data should be rendered correctly';

    # Centre.
    $field = $self->class_to_test->new(
        width     => 20,
        alignment => 'centre',
    );
    is $field->as_string($string), 'Did you see the c...',
        'truncated, centre aligned data should be rendered correctly';
    
    # Right.
    $field = $self->class_to_test->new(
        width     => 20,
        alignment => 'right',
    );
    is $field->as_string($string), "...r? It's hovering.",
        'truncated, right aligned data should be rendered correctly';
}

# Testing formatting when a truncator is supplied by the user.
sub data_user_truncator {
    my $self = shift;
    my $field;
    my $string = "Did you see the chandelier? It's hovering.";
    
    # Left.
    $field = $self->class_to_test->new(
        width     => 20,
        alignment => 'left',
        truncator => TCO::String::Truncator->new(
            method => 'beginning',
            length => 20,
        ),
    );
    is $field->as_string($string), "...r? It's hovering.",
        'data should be rendered correctly with user specified truncator';
}

sub default_field {
    my $self = shift;
    return $self->class_to_test->new(
        width     => 20,
        alignment => 'left',
    );
}

1;
