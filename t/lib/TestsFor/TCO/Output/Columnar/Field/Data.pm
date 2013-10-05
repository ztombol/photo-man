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
        alignment => 'left',
        width     => 19,
        truncator => TCO::String::Truncator->new(
            method => 'beginning',
            length => 19,
        ),
    };
}

sub alignment : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my $attributes = $self->default_attributes;

    # Valid alignments.
    foreach ( qw/left centre right/ ) {
        $attributes->{ alignment } = $_;
        lives_ok { $self->_create_field( $attributes ) }
            "trying to create a data field with '$_' alignment should succeed";
    }

    # Invalid alignment.
    $attributes->{ alignment } = 'invalid';
    throws_ok { $self->_create_field( $attributes ) }
        qr/does not pass the type constraint/,
        "trying to create a data field with an invalid alignment should fail";
}

sub truncator : Tests {
    my $self = shift;
    my $field = $self->default_field;
    my $class = $self->class_to_test;

    # Setting non-truncator object.
    throws_ok { $field->set_truncator( $field ) }
        qr/does not pass the type constraint/,
        "trying to set a non-truncator object as 'truncator' should fail";
    
    # Setting truncator object.
    lives_ok { $field->set_truncator(
            TCO::String::Truncator->new(
                method => 'beginning',
                length => 20,
            )
        ) }
        "trying to set a truncator object as 'truncator' should succeed";

    # Default truncation methods for each alignment.
    my %alignment_method = (
        left   => 'end',
        centre => 'end',
        right  => 'beginning',
    );

    # Field attributes.
    my $attributes = $self->default_attributes;
    delete $attributes->{ truncator };

    while ( my ($alignment, $method) = each %alignment_method ) {
        $attributes->{ alignment } = $alignment;
        my $field = $self->_create_field( $attributes );

        my $want = TCO::String::Truncator->new(
            method => $method,
            length => $attributes->{ width },
        );
        eq_or_diff $field->get_truncator, $want,
            "'$alignment' aligned field should be truncated at the '$method' by default";
    }
}

sub type : Tests {
    my $self = shift;
    my $field = $self->default_field;

    is $field->get_type, 'data',
        "correct type should be set implicitly";
}

sub width : Tests {
    my $self = shift;
    my $field = $self->default_field;

    # Non-positive width.
    throws_ok { $field->set_width( 0 ) }
        qr/does not pass the type constraint/,
        "trying to set a non-positive 'width' should fail";
    
    # Positive width.
    lives_ok { $field->set_width( 1 ) }
        "trying to set a positive 'width' should succeed";
}

sub as_string : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my ( $field, $string );
    
    # Field attributes.
    my $attributes = $self->default_attributes;
    delete $attributes->{ truncator };
    $attributes->{ width } = 19;

    # Padding.
    $string = 'Shiny!';

    my %alignment_result = (
        left   => 'Shiny!             ',
        right  => '             Shiny!',
        centre => '      Shiny!       ',
    );

    while ( my ($alignment, $result) = each %alignment_result ) {
        $attributes->{ alignment } = $alignment;
        my $field = $self->_create_field( $attributes );

        is $field->as_string( $string ), $result,
            "'$alignment' aligned data should be padded correctly";
    }

    # Truncating.
    $string = "Did you see the chandelier? It's hovering.";
    
    %alignment_result = (
        left   => 'Did you see the ...',
        right  => "...? It's hovering.",
        centre => 'Did you see the ...',
    );
    
    while ( my ($alignment, $result) = each %alignment_result ) {
        $attributes->{ alignment } = $alignment;
        my $field = $self->_create_field( $attributes );

        is $field->as_string( $string ), $result,
            "'$alignment' aligned data should be truncated correctly";
    }
}

1;
