#
# Copyright (C)  2013  Zoltan Vass <zoltan.vass.2k6 (at) gmail (dot) com>
#

#
# This file is part of photo-man.
#
# photo-man is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# photo-man is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with photo-man.  If not, see <http://www.gnu.org/licenses/>.
#


package TestsFor::TCO::Output::Columnar::Field::Data;

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
        width     => 20,
        alignment => 'left',
    );
}

sub as_string : Tests {
    my $self = shift;

    # Test rendering with all kinds of data.
    $self->data_padding;
    $self->data_truncation;
    $self->data_user_truncator;
}

# Testing padding with data that is shorter than the field.
sub data_padding {
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

# Testing truncation with data that is longer than the field.
sub data_truncation {
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

# Testing truncation with user specified truncators.
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

1;
