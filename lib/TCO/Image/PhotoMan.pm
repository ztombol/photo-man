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


# Class implementing photo management related functions.
package TCO::Image::PhotoMan;

use Moose;
use MooseX::StrictConstructor;
use MooseX::FollowPBP;
use namespace::autoclean;
use Carp;

use TCO::Image::File;

use File::Compare;
use DateTime;
use DateTime::Format::Strptime;

our $VERSION = '0.1';
$VERSION = eval $VERSION;

# Make changes to files (1) or not (0).
has 'commit' => (
    is       => 'ro',
    isa      => 'Bool',
    default  => 0,
    reader   => 'do_commit',
);

# Execute destructive operations such as overwriting (1) or not (0).
has 'forced' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
    reader  => 'is_forced',
);

# Moves the image to a new location and/or renames it. The new location and
# filename is specified with templates that lets the user to combine string
# literals and parts of the creation timestamp from the metadata of the image.
#
# NOTE: As a side-effect, this function also updates the `path' in the image
# object and thus reloads metadata.
#
# @param [in] image          to move and/or rename
# @param [in] location_temp  template used to produce the new location for
#			     moving
# @param [in] filename_temp  template used to produce the new filename for
#                            renaming
#
# returns  -2, timestamp missing
#          -1, in case of errors
#           0, successful moving/renaming
#           1, file at the destination overwritten
#           2, another file already exists with the same path
#           3, the file is already at the given path
sub move_and_rename {
    my $self = shift;
    my $args_ref;
    my $status;

    # Accept attributes in a hash or a hashref.
    if ( @_ == 1 && (ref $_[0] eq 'HASH') ) { $args_ref = shift; }
    else                                    { $args_ref = {@_};  }

    my $image         = $args_ref->{image};
    my $location_temp = $args_ref->{location_temp};
    my $filename_temp = $args_ref->{filename_temp};
    my $use_libmagic  = $args_ref->{use_libmagic};

    # New path of the file.
    my $new_file;

    # Retrieve timestamp for interpolation.
    my $timestamp = $image->get_timestamp('CreateDate');
    if ( ! defined $timestamp ) {
        # EXIF DateTimeDigitized is not present in metadata.
        $status = -2;
    }
    else {
        # Assemble new path.
        $new_file = $self->_make_path( $image, $location_temp, $filename_temp, $timestamp, $use_libmagic);

        # Attempt to move the file.
        if ( ! -e $new_file ) {
            # Target file does not exists. Move the file!
            if ( $self->do_commit ) {
                $image->move_file( $new_file );
            }
            $status = 0;
        }
        elsif ( $image->get_path eq $new_file ) {
            # Source and Target are the same. Nothing to do!
            $status = 3;
        }
        else {
            # There exists a file at the Target already.
            my $cmp = compare( $image->get_path, $new_file );
            if ( $cmp == 1 ) {
               # Target is different from Source. Can we overwrite?
               if ( $self->is_forced ) {
                   # Overwrite file.
                   if ( $self->do_commit ) {
                       $image->move_file( $new_file );
                    }
                    $status = 1;
                }
                else {
                    # Do not overwrite file.
                    $status = 2;
                }
            }
            elsif ( $cmp == 0 ) {
                # Source and Target are the same file. Nothing to do!
                $status = 2;
            }
        }
    }

    # Return status code.
    # FIXME: this is a work around until we implement journaling on file
    #        operations
    return ($status, $new_file);
    #return $status;
}

# Creates a path based on location (for directory) and filename templates (for
# the actual filename portion). The path is created by interpolating the
# template with parts of the DateTimeDigitized timestamp stored in the image's
# metadata.
# The templates are optional. If a template is not supplied, the original value
# will be used. For example, a template is specified for location but not for
# filename then the new path will consist of the new location and the original
# filename.
# The original extension (portion of filename after the last dot) will be used,
# unless the last parameter is true. In which case LibMagic is used to
# determine the extension.
#
# @param [in] $1  image to create path for
# @param [in] $2  location template (optional)
# @param [in] $3  filename template (optional)
# @param [in] $4  0: use substring after the last dot, or
#                 1: use LibMagic to determine extension
#
# returns the produced path
sub _make_path {
    my $self = shift;

    my $image         = shift;
    my $location_temp = shift;
    my $filename_temp = shift;
    my $timestamp     = shift;
    my $use_libmagic  = shift;
   
    # Parent directory. 
    my $new_location = ( defined $location_temp && $location_temp ne '' )
      ? $self->_template_to_str( $location_temp, $timestamp )
      : $image->get_dir;

    # Filename including extension.
    my $new_filename = (( defined $filename_temp && $filename_temp ne '' )
      ? $self->_template_to_str( $filename_temp, $timestamp )
      : $image->get_filename )
        . '.' . $image->get_extension( $use_libmagic );

    return File::Spec->catfile( $new_location, $new_filename );
}

# Constructs string from a template by interpolating it using the creation
# timestamp from metadata stored in the image.
#
# @param [in] image     to extract metadata from
# @param [in] template  string to interpolate
#
# returns produced string
sub _template_to_str {
    my $self = shift;
    my $template = shift;
    my $timestamp = shift;

    # Return interpolated string.
    return $timestamp->strftime( $template );
}

# Sets the file system modification timestamp to the EXIF *digitised* timestamp
# that is correctly offset by the time difference between the original (where the photo was
# taken) and the local timezone (where the file system lives).
#
# @param [in] image     whose timestamp will be modified
# @param [in] timezone  where the photo was taken
#
# returns  -2 timestamp missing
#          -1 error modifying file system timestamp
#           0 timestamp successfully changed
#           1 timestamp already correct
sub fix_timestamp {
    my $self = shift;
    my $args_ref;
    my $status;

    # Accept parameters in a hash or a hashref.
    if ( @_ == 1 && (ref $_[0] eq 'HASH') ) { $args_ref = shift; }
    else                                    { $args_ref = {@_};  }

    my $image     = $args_ref->{image};
    my $time_zone = $args_ref->{timezone};

    # Cache local timezone (retrival can be expensive).
    my $local_tz = DateTime::TimeZone->new( name => 'local' );

    # TODO: Move this into a separate method on Image::File.
    # File system timestamp.
    my $fs_mtime = DateTime->from_epoch(
        epoch     => $image->get_fs_meta->mtime,
        time_zone => $local_tz,
    );
    
    # EXIF creation timestamp.
    my $img_mtime = $image->get_timestamp('CreateDate', $time_zone);
    if ( ! defined $img_mtime ) {
        # EXIF DateTimeDigitized is not present in metadata.
        $status = -2;
    }
    else {
        # Convert embedded timestamp to local time zone.
        $img_mtime->set_time_zone( $local_tz );

        if (   $img_mtime->truncate(to => 'second')
            != $fs_mtime->truncate( to => 'second') ) {

            # Needs to be fixed.
           	if ( $self->do_commit ) { $status = $image->set_mod_time($img_mtime) }
            else                    { $status = 0; }
        }
        else {
            # Timestamp correct.
            $status = 1;
        }
    }

    # Already correct.
    # FIXME: this is a work around until we implement journaling on file
    #        operations
    return ($status, $img_mtime);
    #return $status;
}

__PACKAGE__->meta->make_immutable;

1;
