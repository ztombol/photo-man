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
    parent => 'TestsFor::TCO::Output::Columnar::Field::Data';

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

# Instantiates a new elastic field and resizes it to the given width.
sub _create_field {
    my $self = shift;
    my $attributes = shift;
    my $class = $self->class_to_test;

    my $field = $self->next::method( $attributes );
    $field->resize( $attributes->{ width } );

    return $field;
}

# Attributes of the default object.
sub _default_attributes {
    return {
        ratio     => 1,
        width     => 1,
        alignment => 'left',
    };
}


sub ratio : Tests {
    my $self = shift;
    my $field = $self->default_field;

    # Non-positive ratio.
    throws_ok { $field->set_width( 0 ) }
        qr/does not pass the type constraint/,
        "trying to set a non-positive 'ratio' should fail";
    
    # Positive ratio.
    lives_ok { $field->set_width( 1 ) }
        "trying to set a positive 'ratio' should succeed";
}

sub type : Tests {
    my $self = shift;
    my $field = $self->default_field;

    # Positive width.
    is $field->get_type, 'elastic',
        "correct type should be set implicitly";
}

sub _default_truncator {
    my $self = shift;
    my $class = $self->class_to_test;

    # Default truncation methods for each alignment.
    my %alignment_method = (
        left   => 'end',
        centre => 'end',
        right  => 'beginning',
    );

    while ( my ($alignment, $method) = each %alignment_method ) {
        my $field = $self->_create_field(
            alignment => $alignment,
            ratio     => 1,
            width     => 1,
        );

        my $want = TCO::String::Truncator->new(
            method => $method,
            length => 1,
        );

        eq_or_diff $field->get_truncator, $want,
            "'$alignment' aligned field should be truncated at the '$method' by default";
    }
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
