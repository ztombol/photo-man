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


package TCO::String::Truncator;

use Moose;
use MooseX::FollowPBP;
use namespace::autoclean;
use Carp 'croak';

our $VERSION = '0.1';
$VERSION = eval $VERSION;

# Method of truncation specifying how and which parts to cut.
has 'method' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    reader   => '_get_method',
);

# Maximum length of the truncated string.
has 'length' => (
    is       => 'ro',
#    isa      => 'TCO::String::Types::NonNegativeInteger',
    isa      => 'Int',
    required => 1,
    reader   => '_get_length',
);

# String where cutting is allowed. If set to the empty string '' truncation can
# happen anywhere (default).
has 'delimiter' => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
    reader  => '_get_delimiter'
);

# String to use in place of the cut parts.
has 'ellipsis' => (
    is      => 'ro',
    isa     => 'Str',
    default => '...',
    reader  => '_get_ellipsis',
);

# Truncates a string according to the parameters passed to the constructor.
sub truncate {
    my $self = shift;
    my $string = shift;

    if ( $self->_get_length >= length $string ) {
        # String is short enough, no need to truncate.
        return $string;
    }

    my $ellip = $self->_get_ellipsis;
    my $delim = $self->_get_delimiter;
    my $max_length = $self->_get_length - length $ellip;

    if ( $self->_get_method eq 'end' ) {
        # Cut the excess at the end.
        $string =~ s/\A(.{0,$max_length})$delim.*\Z/$1$ellip/;
        return $string;
    }
    elsif ( $self->_get_method eq 'beginning' ) {
        # Cut the excess at the beginning.
        $string =~ s/\A.*?$delim(.{0,$max_length})\Z/$ellip$1/;
        return $string;
    }
}

__PACKAGE__->meta->make_immutable;

1;

