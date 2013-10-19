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


# Class representing an digital image file.
package TCO::Image::File::Image;

use Moose;
use MooseX::StrictConstructor;
use MooseX::FollowPBP;
use namespace::autoclean;
use Carp;

extends 'TCO::Image::File';

use Image::ExifTool;
use File::stat;
use File::Copy;
use File::Path qw(make_path);
use File::LibMagic;

our $VERSION = '0.2';
$VERSION = eval $VERSION;

# Image metadata.
has 'img_meta' => (
    is       => 'rw',
    isa      => 'Ref',
    reader   => 'get_img_meta',
    writer   => '_set_img_meta',
    clearer  => '_clear_img_meta',
    lazy     => 1,
    builder  => '_load_img_meta',
);

# ExifTool object for metadata operations, e.g. reading/writing tags.
has 'exiftool' => (
    is      => 'ro',
    isa     => 'Ref',
    reader  => '_get_exiftool',
    writer  => '_set_exiftool',
    default => sub { new Image::ExifTool },
);

# Returns image metadata (e.g. EXIF timestamps, geotag) of the file with the
# currently set path.
#
# @param [in] $0  self
#
# @returns  a hashref containing the image metadata
sub _load_img_meta {
    local $_;
    my $self = shift;

    # Extract metadata.
    $self->_set_exiftool( new Image::ExifTool );
    return $self->_get_exiftool->ImageInfo( $self->get_path );
}

# Clears file system and image metadata, so that it will get reloaded
# automatically when accessed next time.
#
# @param [in] $0  self
sub _clear_meta {
    my $self = shift;
    $self->next::method;
    $self->_clear_img_meta;
}

# Returns the EXIF DateTimeDigitized timestamp in the form of a DateTime
# object. If parsing fails because the timestamp is missing (or for some other
# reason) undef is returned.
# The time zone of the DateTime object can be specified via the optional
# parameter that default to 'floating' if not given.
#
# @param [in] $0  self
# @param [in] $1  time zone to set on the DateTime object
#
# @returns  DateTime representation of the EXIF DateTimeDigitized, or
#           undef if timestamp is not in metadata (or parsing has failed)
sub get_exif_digitized {
    my $self = shift;
    my $time_zone = shift || 'floating';

    # Parse date and create a DateTime object.
    my $parser = DateTime::Format::Strptime->new(
        pattern   => '%Y:%m:%d %H:%M:%S',
        time_zone => $time_zone,
    );
    my $timestamp = $parser->parse_datetime(
        $self->get_img_meta->{ 'CreateDate' }
    );

    return (defined $timestamp && $timestamp ne 'undef') ? $timestamp : undef;
}

__PACKAGE__->meta->make_immutable;

1;
