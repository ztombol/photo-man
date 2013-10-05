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


package TestsFor::TCO::Output::Columnar::Field::Stop;

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
    # Set default attributes and default field object.
    $self->default_attributes( $self->_default_attributes );
    $self->default_field( $self->_create_field( $self->default_attributes ) );
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

# Instantiates a new field.
sub _create_field {
    my $self = shift;
    my $class = $self->class_to_test;

    return $class->new;
}

# Attributes of the default object.
sub _default_attributes {
    return {};
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

sub type : Tests {
    my $self = shift;
    my $field = $self->default_field;

    is $field->get_type, 'stop',
        "correct type should be set implicitly";
}

1;
