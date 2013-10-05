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

package TCO::String::Truncator::Types;

use Moose::Util::TypeConstraints;

subtype 'TCO::String::Truncator::Types::Length',
    => as      'Int'
    => where   { $_ > 0 }
    => message { "Truncation lenght must be a positive integer, you specified $_" };

subtype 'TCO::String::Truncator::Types::Method'
    => as      'Str'
    => where   { $_ eq 'beginning' || $_ eq 'end' }
    => message { "Truncation method must be one of `beginning' or `end', you specified $_" };

1;
