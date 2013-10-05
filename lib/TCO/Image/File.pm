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
package TCO::Image::File;

use Moose;
use MooseX::StrictConstructor;
use MooseX::FollowPBP;
use namespace::autoclean;
use Carp;

use Image::ExifTool;
use File::stat;
use File::Copy;
use File::Path qw(make_path);
use File::LibMagic;

our $VERSION = '0.2';
$VERSION = eval $VERSION;

# Filename of image.
has 'path' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    reader   => 'get_path',
    writer   => '_set_path',
    trigger  => \&_reload_meta,
);

# EXIF metadata associated with the image.
has 'img_meta' => (
    is       => 'rw',
    isa      => 'Ref',
    reader   => 'get_img_meta',
    writer   => '_set_img_meta',
    lazy     => 1,
    builder  => '_load_img_meta',
);

# File system metadata.
has 'fs_meta' => (
    is      => 'rw',
    isa     => 'Ref',
    reader  => 'get_fs_meta',
    writer  => '_set_fs_meta',
    lazy    => 1,
    builder => '_load_fs_meta',
);

# Exiftool object for metadata operations, e.g. reading/writing tags.
has 'exiftool' => (
    is      => 'ro',
    isa     => 'Ref',
    reader  => '_get_exiftool',
    default => sub { new Image::ExifTool },
);

# Loads file system metadata, e.g. timestamps, ownership, permissions, etc.
#
# @returns a File::stat object containing the file system metadata
sub _load_fs_meta {
    local $_;
    my $self = shift;

    return stat( $self->get_path );
}

# Loads metadata found in the image file, e.g. EXIF, IPTC, XMP, etc.
#
# @returns a hashref containing metadata embedded in the image file
sub _load_img_meta {
    local $_;
    my $self = shift;

    # Extract metadata.
    my $exif_tool = new Image::ExifTool;
    return $exif_tool->ImageInfo( $self->get_path );
}

# Reloads file system and image embedded metadata. Triggered when path is
# changed.
sub _reload_meta {
    my ( $self, $new_path, $old_path ) = @_;
    $self->_set_fs_meta( $self->_load_fs_meta );
    $self->_set_img_meta( $self->_load_img_meta );
}

# Returns the basename of the file (filename and extension).
#
# @param [in] $0  file object
# returns basename including extension
sub get_basename {
    my $self = shift;
    return (File::Spec->splitpath( $self->get_path ))[2];
}

# Returns the filename (basename without the extension and dot).
#
# @param [in] $0  file object
#
# @returns  filename without extension
sub get_filename {
    my $self = shift;
    $self->get_path =~ m{([^/]+?).[^.]+\Z};
    return $1;
}

# Returns the extension of the file (portion after the last dot). The extension
# can be determined from the basename (default) or using the magic number of
# the file.
#
# @param [in] $0  file object
# @param [in] $1  use LibMagic to get extension?
#
# @returns  extension
sub get_extension {
    my $self = shift;
    my $use_magic = shift || 0;

    if ( $use_magic ) {
        my $magic = File::LibMagic->new();
        $magic->checktype_filename($self->get_path) =~ m{image/(.*?);};
        return $1;
    }
    else {
        $self->get_path =~ /\.([^.]+)\Z/;
        return $1;
    }
}

# Returns the parent directory of the file.
#
# @param [in] $0  file object
# returns parent parent directory
sub get_dir {
    my $self = shift;
    return File::Spec->canonpath( (File::Spec->splitpath( $self->get_path ))[1] );
}

# Returns a DateTime object representing the requested timestamp.
#
# @param [in] $0  file object
# @param [in] $1  name of requested timestamp (for available tags see:
#                 http://www.sno.phy.queensu.ca/~phil/exiftool/TagNames/EXIF.html)
# @param [in] $2  time zone of the timestamp, defaults to 'floating'
# @returns DateTime representation of therequest EXIF timestamp
sub get_timestamp {
    my $self = shift;
    my $tag_name = shift;
    my $time_zone = shift || 'floating';

    # Parse date and create a DateTime object.
    my $parser = DateTime::Format::Strptime->new(
        pattern   => '%Y:%m:%d %H:%M:%S',
        time_zone => $time_zone,
    );
    my $timestamp = $parser->parse_datetime(
        $self->get_img_meta->{ $tag_name }
    );

    return $timestamp;
}

# Moves the file and creates the directories leading up to the new location if
# they do not exist already. Upon success the file system and image metadata
# will be reloaded.
#
# @param [in] $1  new path of file (includes filename)
# return  0 on success
#         1 otherwise
sub move_file {
    my $self = shift;
    my $dest = shift;

    # Make sure the directory tree exists up to the destination.
    make_path( (File::Spec->splitpath($dest))[1] );

    my $result;
    if ( $result = move($self->get_path, $dest) ) {
        # File moved successfully. Update path and thus metadata.
        $self->_set_path( $dest );
    }

    # Flip result. move returns 1 on success and 0 on error.
    return not $result;
}

# Same as above just using exiftool to move the file and create necessary
# directories.
#sub move_file {
#    my $self = shift;
#    my $dest = shift;
#
#    my $exif_tool = new Image::ExifTool;
#
#    # This performs the move immediately
#    my $result = $exif_tool->SetFileName(
#        $self->get_path,
#        $dest,
#    );
#
#    return not $result;
#}

# Changes the file system modification timestamps of the file. Upon success the
# file system and image metadata will be reloaded.
#
# @param [in] mtime  modification timestamp to set (DateTime ref)
# return -1 on error
#         0 on successful timestamp change
sub set_mod_time {
    my $self = shift;
    my $mtime = shift;
    my $exiftool = $self->_get_exiftool;

    # Set new timestamp.
    my ( $success, $err_str ) = $exiftool->SetNewValue(
        FileModifyDate => $mtime,
        Protected      => 1,
    );

    return -1 if ( ! $success );

    # Write timestamp to file system.
    if ( $exiftool->SetFileModifyDate($self->get_path) == 1 ) {
        # Timestamp changed. Reload metadata.
        $self->_reload_meta;
        return 0;
    }

    # Something went wrong.
    return -1;
}

__PACKAGE__->meta->make_immutable;

1;
