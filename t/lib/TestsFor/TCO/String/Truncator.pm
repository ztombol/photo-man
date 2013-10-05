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


package TestsFor::TCO::String::Truncator;

use Test::Class::Most
    parent      =>'TestsFor',
    attributes  => [qw(default_truncator default_attributes)];

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

    # Set default attributes and default field object.
    $self->default_attributes( $self->_default_attributes );
    $self->default_truncator( $self->_create_truncator( $self->default_attributes ) );
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

# Instantiates a new truncator.
sub _create_truncator {
    my $self  = shift;
    my $class = $self->class_to_test;

    return $class->new(
        $self->default_attributes,
    );
}

# Attributes of the default object.
sub _default_attributes {
    return {
        method => 'end',
        length => 10,
    };
}

sub constructor : Tests {
    my $self  = shift;
    my $class = $self->class_to_test;

    can_ok $class, 'new';
    throws_ok { $class->new }
        qr/Attribute.*required/,
        "Creating a $class without proper attributes should fail";
    isa_ok $self->default_truncator, $class;
}

sub method : Tests {
    my $self = shift;
    my $class = $self->class_to_test;

    # Valid methods.
    foreach ( qw/beginning end/ ) {
        $self->default_attributes->{ method } = $_;
        lives_ok { $class->new( $self->default_attributes ) }
            "trying to create a truncator with '$_' method should succeed";
    }

    # Invalid alignment.
    $self->default_attributes->{ method } = 'invalid';
    throws_ok { $class->new( $self->default_attributes ) }
        qr/does not pass the type constraint/,
        "trying to create a truncator with an invalid alignment should fail";
}

sub length : Tests {
    my $self = shift;
    my $truncator = $self->default_truncator;

    # Non-positive width.
    throws_ok { $truncator->set_length( 0 ) }
        qr/does not pass the type constraint/,
        "trying to set a non-positive 'length' should fail";
    
    # Positive width.
    lives_ok { $truncator->set_length( 1 ) }
        "trying to set a positive 'length' should succeed";
}

sub delimiter : Tests {
    my $self = shift;
    my $truncator = $self->default_truncator;

    is $truncator->_get_delimiter, '',
        "delimiter should be set to the empty string by default";
}

sub ellipsis : Tests {
    my $self = shift;
    my $truncator = $self->default_truncator;

    is $truncator->_get_ellipsis, '...',
        "ellipsis should be set to '...' by default";
}

sub truncate : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my $string = 'The quick brown fox jumps over the lazy dog.';
    my $truncator;
    
    # No truncation.
    $truncator = $class->new(
        method    => 'beginning',
        length    => CORE::length( $string ),
    );
    is $truncator->truncate( $string ), $string,
        "short enough string should be left untouched";

    # Beginning.
    $truncator = $class->new(
        method    => 'beginning',
        length    => '24',
        delimiter => ' ',
    );
    is $truncator->truncate( $string ), '...over the lazy dog.',
        "truncating at the beginning should be done correctly";

    # End.
    $truncator = $class->new(
        method    => 'end',
        length    => '20',
        delimiter => ' ',
    );
    is $truncator->truncate( $string ), 'The quick brown...',
        "truncating at the end should be done correctly";

    # Empty string delimiter.
    $truncator = $class->new(
        method => 'beginning',
        length => '20',
    );
    is $truncator->truncate( $string ), '...ver the lazy dog.',
        "the empty string delimiter should cut anywhere, even in the middle of a 'word'";

    # Custom ellipsis.
    $truncator = $class->new(
        method   => 'beginning',
        length   => '21',
        ellipsis => '..',
    );
    is $truncator->truncate( $string ), '.. over the lazy dog.',
        "truncation should be correct with custom ellipsis";
}

1;
