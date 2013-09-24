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
    attributes  => [qw(default_truncator)];

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

    # Instantiate default field object.
    $self->default_truncator(
        $class->new(
            method => 'end',
            length => 10,
        )
    );
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

sub constructor : Tests {
    my $self  = shift;
    my $class = $self->class_to_test;

    can_ok $class, 'new';
    throws_ok { $class->new }
        qr/Attribute.*required/,
        "Creating a $class without proper attributes should fail";
    isa_ok $self->default_truncator, $class;
}

sub attributes : Tests {
    my $self = shift;
    my $field = $self->default_truncator;
    my %default_attributes;

    # Getters.
    %default_attributes = (
        length    => '10',
    );

    while (my ($attribute, $value) = each %default_attributes) {
        my $getter = "get_$attribute";
        can_ok $field, $getter;
        eq_or_diff $field->$getter(), $value,
            "getter for '$attribute' should be correct";
    }
    
	# Setters.
    %default_attributes = (
        length    => '20',
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

sub truncate : Tests {
    my $self = shift;

    # Test different truncation methods.
    $self->truncate_at_beginning;
    $self->truncate_at_end;
}

# Removing excess at the beginning.
sub truncate_at_beginning {
    my $self  = shift;
    my $class = $self->class_to_test;

    # Test strings with one and multi-character delimiters.
    my $one_char_delim = 'The quick brown fox jumps over the lazy dog.';
    my $four_char_delim = 'pear----apple----cabbage----tomato----banana';
    my $trunc;

    # Default.
    $trunc = $class->new({
        method => 'beginning',
        length => '20',
    });
    is $trunc->truncate($one_char_delim), '...ver the lazy dog.',
        'beginning: truncation should be correct with default delimiter and ellipsis';

    # Delimiter.
    $trunc = $class->new({
        method    => 'beginning',
        length    => length $one_char_delim,
    });
    is $trunc->truncate($one_char_delim), $one_char_delim,
        'beginning: truncation should not happen when target is short enough';

    # Delimiter longer than ellipsis.
    $trunc = $class->new({
        method    => 'beginning',
        length    => '18',
        ellipsis  => '..',
        delimiter => '----',
    });
    is $trunc->truncate($four_char_delim), '..tomato----banana',
        'beginning: truncation should be correct when the delimiter is longer'
      . ' than ellipsis';
}

# Removing excess at the end.
sub truncate_at_end {
    my $self  = shift;
    my $class = $self->class_to_test;

    # Test strings with one and multi-character delimiters.
    my $one_char_delim = 'The quick brown fox jumps over the lazy dog.';
    my $four_char_delim = 'pear----apple----cabbage----tomato----banana';
    my $trunc;

    # Default.
    $trunc = $class->new({
        method => 'end',
        length => '20',
    });
    is $trunc->truncate($one_char_delim), 'The quick brown f...',
        'end: truncation should be correct with default delimiter and ellipsis';

    # Delimiter.
    $trunc = $class->new({
        method    => 'end',
        length    => length $one_char_delim,
    });
    is $trunc->truncate($one_char_delim), $one_char_delim,
        'end: truncation should not happen when target is short enough';

    # Delimiter longer than ellipsis.
    $trunc = $class->new({
        method    => 'end',
        length    => '18',
        ellipsis  => '..',
        delimiter => '----',
    });
    is $trunc->truncate($four_char_delim), 'pear----apple..',
        'end: truncation should be correct when the delimiter is longer than '
      . 'ellipsis';
}

1;
