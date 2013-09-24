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


# A 'rubbery' data field whose width is given with a ratio specifying what
# fraction of the remaining space, after reserving space for static sized
# fields, the field can take up comparing to other elastic fields.
package TCO::Output::Columnar::Field::Data::ElasticData;

use Moose;
use namespace::autoclean;
use MooseX::FollowPBP;
use MooseX::StrictConstructor;
use Carp 'croak';

extends 'TCO::Output::Columnar::Field::Data';

our $VERSION = '0.1';
$VERSION = eval $VERSION;

use TCO::Output::Columnar::Types;
#use TCO::String::Truncator;

# Number of characters the field can occupy.
has 'ratio' => (
    is       => 'ro',
    isa      => 'TCO::Output::Columnar::Types::ElasticityRatio',
    required => 1,
);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my $args_ref;

    # Accept attributes in a hash or a hashref.
    if ( @_ == 1 && (ref $_[0] eq 'HASH') ) { $args_ref = shift; }
    else                                    { $args_ref = {@_};  }

    $args_ref->{type} = 'elastic';
    return $class->$orig( $args_ref );
};

# Sets a new width for the field and its truncator.
sub resize {
    my $self = shift;
    my $width = shift;

    $self->set_width( $width );
    $self->get_truncator->set_length( $width );
}

__PACKAGE__->meta->make_immutable;

1;
