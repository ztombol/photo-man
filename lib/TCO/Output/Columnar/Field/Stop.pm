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


# Control field used to specify the end of a field group. When printing fields,
# all fields in a groups are processed in order until a `stop' field is
# encountered.
package TCO::Output::Columnar::Field::Stop;

use Moose;
use MooseX::StrictConstructor;
use MooseX::FollowPBP;
use namespace::autoclean;
use Carp;

extends 'TCO::Output::Columnar::Field';

our $VERSION = '0.1';
$VERSION = eval $VERSION;

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    if ( @_ != 0 ) {
        croak "Error: constructor requires no parameters!";
    }

    return $class->$orig(
        type => 'stop',
    );
};

__PACKAGE__->meta->make_immutable;

1;
