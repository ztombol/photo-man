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


package TestsFor::TCO::Output::Columnar::Field::Literal;

use Test::Class::Most
    parent => 'TestsFor::TCO::Output::Columnar::Field';

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

# Attributes of the default object.
sub _default_attributes {
    return {
        string => "It's okay, I'm a leaf on the wind.",
    };
}

sub type : Tests {
    my $self = shift;
    my $field = $self->default_field;

    is $field->get_type, 'literal',
        "correct type should be set implicitly";
}

sub get_width : Tests {
    my $self = shift;
    my $field = $self->default_field;

    is $field->get_width, length $self->default_attributes->{ string },
        "'get_width' should return the length of the string";
}

sub as_string : Tests {
    my $self = shift;
    my $field = $self->default_field;

    is $field->as_string, $self->default_attributes->{ string },
        "'as_string' should return the string"
}

1;
