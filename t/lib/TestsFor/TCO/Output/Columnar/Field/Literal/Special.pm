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


package TestsFor::TCO::Output::Columnar::Field::Literal::Special;

use Test::Class::Most
    parent      => 'TestsFor::TCO::Output::Columnar::Field::Literal';

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
        string => "\r",
    );
}

sub attributes : Tests {
    my $self = shift;
    my $field = $self->default_field;
    my %default_attributes;
    
    # Getters.
    %default_attributes = (
        type   => 'special',
        width  => 0,
    );

    while (my ($attribute, $value) = each %default_attributes) {
        my $getter = "get_$attribute";
        can_ok $field, $getter;
        eq_or_diff $field->$getter(), $value,
            "getter for '$attribute' should be correct";
    }
}

sub as_string : Tests {
    my $self = shift;
    my $string = "\r";

    my $field = $self->class_to_test->new({
        string => $string,
    });
    is $field->as_string(), $string,
        'field should render the string correctly';
}

1;
