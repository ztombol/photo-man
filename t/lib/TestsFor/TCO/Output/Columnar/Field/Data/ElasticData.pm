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


package TestsFor::TCO::Output::Columnar::Field::Data::ElasticData;

use Test::Class::Most
    parent      => 'TestsFor::TCO::Output::Columnar::Field::Data';

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

    my $field = $class->new(
        ratio     => 1,
        width     => 1,
        alignment => 'left',
    );
    $field->resize( 10 );

    return $field;
}

sub attributes : Tests {
    my $self = shift;
    my $field = $self->default_field;
    my %default_attributes;

    # Getters.
    %default_attributes = (
	type  => 'elastic',
        ratio => 1,
    );

    while (my ($attribute, $value) = each %default_attributes) {
        my $getter = "get_$attribute";
        can_ok $field, $getter;
        eq_or_diff $field->$getter(), $value,
            "getter for '$attribute' should be correct";
    }
}

# FIXME:
# This function is intentionally empty to prevent the parent method to run, as
# it would simply fail.
# We should modify the parent method to use default_field and set_attributes so
# we can test as_string for this subclass too.
sub as_string {
    my $self = shift;
    my $class = $self->class_to_test;

    diag("No tests: Elastic data fields use the same code to render as static fields.");
    return;
}

sub resize : Tests {
    my $self  = shift;
    my $class = $self->class_to_test;
    my $field = $self->default_field;

    $field->resize( 20 );	
    is $field->get_width(), 20,
    	"resize should change the width of the field";
    is $field->get_truncator()->get_length(), 20,
    	"resize should change the length of the field's trunator";
}

1;
