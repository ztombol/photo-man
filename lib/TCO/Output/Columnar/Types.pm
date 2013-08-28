#
# Copyright (C)  2013  Zoltan Vass <zoltan.vass.2k6 (at) gmail (dot) com>
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


package TCO::Output::Columnar::Types;

use Moose::Util::TypeConstraints;

subtype 'TCO::Output::Columnar::Types::FieldWidth'
    => as      'Int'
    => where   { $_ > 0 }
    => message { "Field width must be a positive integer, you specified $_" };

subtype 'TCO::Output::Columnar::Types::FieldAlignment'
    => as      'Str'
    => where   { $_ eq 'left' || $_ eq 'centre' || $_ eq 'right' }
    => message { "Field alignment must be one of `left', `centre' or `right', you specified $_" };

1;
