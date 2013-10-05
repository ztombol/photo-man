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


# Field printing a constant string literal. The string literal is given at
# object creation.
package TCO::Output::Columnar::Field::Literal;

use Moose;
use MooseX::StrictConstructor;
use MooseX::FollowPBP;
use namespace::autoclean;
use Carp;

extends 'TCO::Output::Columnar::Field';

# String to output.
has 'string' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    reader   => '_get_string',
);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my $args_ref;

    # Accept attributes in a hash or a hashref.
    if ( @_ == 1 && (ref $_[0] eq 'HASH') ) { $args_ref = shift; }
    else                                    { $args_ref = {@_};  }

    # Let subclasses specify their own type.
    $args_ref->{type} //= 'literal';

    return $class->$orig( $args_ref );
};

sub get_width {
    my $self = shift;
    return length $self->_get_string;
}

# Produces string representation of field.
sub as_string {
    my $self = shift;
    return sprintf $self->_get_string;
}

__PACKAGE__->meta->make_immutable;

1;
