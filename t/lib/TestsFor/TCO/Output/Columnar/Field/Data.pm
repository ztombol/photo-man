#
# Copyright (C)  2013  Zoltan Vass <zoltan.tombol (at) gmail (dot) com>
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
        width     => 19,
        alignment => 'left',
        truncator => TCO::String::Truncator->new(
            method => 'beginning',
            length => 19,
        ),
    );
}

sub attributes : Tests {
    my $self = shift;
    my $field = $self->default_field;
    my %default_attributes;
    
    # Getters.
    %default_attributes = (
        type      => 'data',
        width     => 19,
        truncator => TCO::String::Truncator->new(
            method => 'beginning',
            length => 19,
        ),
    );

    while (my ($attribute, $value) = each %default_attributes) {
        my $getter = "get_$attribute";
        can_ok $field, $getter;
        eq_or_diff $field->$getter(), $value,
            "getter for '$attribute' should be correct";
    }
    
    # Setters.
    %default_attributes = (
        width     => 29,
        truncator => TCO::String::Truncator->new(
            method => 'beginning',
            length => 29,
        ),
    );

    while (my ($attribute, $value) = each %default_attributes) {
	my $setter = "set_$attribute";
	my $getter = "get_$attribute";
        can_ok $field, $setter;
        $field->$setter( $value );
        eq_or_diff $field->$getter(), $value,
            "setter for '$attribute' should be correct";
    }
}

sub as_string : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my $field;
    my $string;

    #
    # Padding.
    #
    $string = 'Shiny!';

    # Left.
    $field = $class->new(
        width     => 19,
        alignment => 'left',
    );
    is $field->as_string( $string ), 'Shiny!             ',
        'left aligned data should be padded correctly';

    # Right.
    $field = $class->new(
        width     => 19,
        alignment => 'right',
    );
    is $field->as_string( $string ), '             Shiny!',
        'right aligned data should be padded correctly';

    # Centre.
    $field = $class->new(
        width     => 19,
        alignment => 'centre',
    );
    is $field->as_string( $string ), '      Shiny!       ',
        'centred data should be padded correctly';

    #
    # Truncating.
    #
    $string = "Did you see the chandelier? It's hovering.";
    
    # Left.
    $field = $self->class_to_test->new(
        width     => 19,
        alignment => 'left',
    );
    is $field->as_string( $string ), 'Did you see the ...',
        'left aligned data should be truncated correctly';
    
    # Right.
    $field = $self->class_to_test->new(
        width     => 19,
        alignment => 'right',
    );
    is $field->as_string($string), "...? It's hovering.",
        'right aligned data should be truncated correctly';

    # Centre.
    $field = $self->class_to_test->new(
        width     => 19,
        alignment => 'centre',
    );
    is $field->as_string($string), 'Did you see the ...',
        'centred data should be truncated correctly';
}

1;
