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


# Field, printing an arbitrary string aligned on an arbitrarily wide space.
# Alignment and maximum width is given at construction time and payload data
# (string to format) is specified upon printing.
package TCO::Output::Columnar::Field::Data;

use Moose;
use namespace::autoclean;
use MooseX::FollowPBP;
use MooseX::StrictConstructor;
use Carp 'croak';

extends 'TCO::Output::Columnar::Field';

use TCO::Output::Columnar::Types;
use TCO::String::Truncator;

# Number of characters the field can occupy.
has 'width' => (
    is       => 'rw',
    isa      => 'TCO::Output::Columnar::Types::FieldWidth',
    required => 1,
);

# Alignment of the printed data. Can be `left', `right' or `centre'.
has 'alignment' => (
    is       => 'ro',
    isa      => 'TCO::Output::Columnar::Types::FieldAlignment',
    required => 1,
    reader   => '_get_alignment',
);

# Truncator object used to shorten data wider than the field.
has 'truncator' => (
    is      => 'rw',
    # FIXME: can we make this read-only?
    #is      => 'ro',
    isa     => 'TCO::String::Truncator',
    lazy    => 1,
    builder => '_build_truncator',
);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my $args_ref;

    # Accept attributes in a hash or a hashref.
    if ( @_ == 1 && (ref $_[0] eq 'HASH') ) { $args_ref = shift; }
    else                                    { $args_ref = {@_};  }

    # Let subclasses specify their own type.
    $args_ref->{type} //= 'data';

    return $class->$orig( $args_ref );
};

# Builder method. Initialises truncator when one is not supplied to the
# constructor. Truncation method depends on the alignment.
sub _build_truncator {
    local $_;
    my $self = shift;

    my $method = $self->_get_alignment eq 'right' ? 'beginning'
                                                  : 'end';
    return TCO::String::Truncator->new(
        method => $method,
        length => $self->get_width,
    );
}

# Renders the string representation of the field.
sub as_string {
    my $self = shift;
    my $data = shift;

    # Truncate data if necessary.
    $data = $self->get_truncator->truncate( $data );

    if ( $self->_get_alignment eq 'centre' ) {
        # Centre alignment.
	my $left_pad  = int( ($self->get_width - length $data) / 2 );
	my $right_pad = $self->get_width - ( length($data) + $left_pad );
        return ' ' x $left_pad . $data . ' ' x $right_pad;
    }
    else {
        # Left/Right alignment.
        my $alignment = ($self->_get_alignment eq 'left') ? '-' : '';
        return sprintf( "%${alignment}" . $self->get_width . "s", $data );
    }
}

__PACKAGE__->meta->make_immutable;

1;
