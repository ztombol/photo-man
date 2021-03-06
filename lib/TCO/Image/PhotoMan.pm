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

use TCO::Image::PhotoMan::Log;
use TCO::Image::File::Image;

use File::Compare;
use DateTime;
use DateTime::Format::Strptime;

our $VERSION = '0.2';
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

has 'log' => (
    is      => 'ro',
    isa     => 'TCO::Image::PhotoMan::Log',
    default => sub { TCO::Image::PhotoMan::Log->new },
    reader  => '_get_log',
);

# Sets the file system modification timestamp to the EXIF digitised timestamp
# that is correctly offset by the time difference between the original (where
# the photo was taken) and the local timezone (where the file system lives).
#
# @param [in] image     whose timestamp will be modified
# @param [in] timezone  where the photo was taken
#
# @returns -2 timestamp missing
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

    # File system timestamp.
    my $fs_mtime = $image->get_mtime;

    # EXIF creation timestamp.
    my $img_mtime = $image->get_exif_digitized( $time_zone );
    if ( ! defined $img_mtime ) {
        # EXIF DateTimeDigitized is not present in metadata (or could not be
        # parsed, which is less likely to happen though).
        $status = -2;
    }
    else {
        # Convert embedded timestamp to local time zone.
        $img_mtime->set_time_zone( $local_tz );

        if (   $img_mtime->truncate(to => 'second')
            != $fs_mtime->truncate( to => 'second') ) {

            # Needs to be fixed.
            if ( $self->do_commit ) {
                $status = $image->set_mtime( $img_mtime );
            }
            else {
                $status = 0;
            }
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


# Moves the image to a new location and/or renames it. The new location and
# file name is specified with templates that lets the user to combine string
# literals and parts of the DateTimeDigitized timestamp from the EXIF metadata
# of the image.
#
# NOTE: As a side-effect, this function also updates the `path' in the image
#       object and thus reloads metadata.
#
# @param [in] image           to move and/or rename
# @param [in] location_temp   template used to produce the new location for
#                             moving
# @param [in] file_name_temp  template used to produce the new filename for
#                             renaming
#
# @returns -2, timestamp missing
#          -1, error while moving
#           0, successful moving/renaming
#           1, file at the destination overwritten
#           2, another file already exists with the same path
#           3, the file is already at the given path
#           4, destination collides with that of another file
sub move_and_rename {
    my $self = shift;
    my $args_ref;
    my $status;

    # Accept attributes in a hash or a hashref.
    if ( @_ == 1 && (ref $_[0] eq 'HASH') ) { $args_ref = shift; }
    else                                    { $args_ref = {@_};  }

    my $image          = $args_ref->{image};
    my $location_temp  = $args_ref->{location_temp};
    my $file_name_temp = $args_ref->{file_name_temp};
    my $use_magic      = $args_ref->{use_magic};

    # New path of the file.
    my $new_file;

    # Retrieve timestamp for interpolation.
    my $timestamp = $image->get_exif_digitized;
    if ( ! defined $timestamp ) {
        # EXIF DateTimeDigitized is not present in metadata (or could not be
        # parsed, which is less likely to happen though).
        $status = -2;
    }
    else {
        # Assemble new path.
        $new_file = $self->_make_path(
            image          => $image,
            timestamp      => $timestamp,
            location_temp  => $location_temp,
            file_name_temp => $file_name_temp,
            use_magic      => $use_magic,
        );

        # Attempt to move the file.
        if ( $self->_get_log->does_file_exist( $new_file ) == 1 ) {
            # Collision with another file moved in this run.
            $status = 4;
        }
        elsif ( ! $self->_does_file_exist( $new_file ) ) {
            # Target file does not exists. Move the file!

            # Log move operation.
            $self->_get_log->move( $image->get_path, $new_file );

            if ( $self->do_commit ) {
                $status = $image->move_file( $new_file ) ? -1 : 0;
            }
            else {
                $status = 0;
            }
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

                # Log move operation.
                $self->_get_log->move( $image->get_path, $new_file );

                if ( $self->is_forced ) {
                    # Overwrite file.
                    if ( $self->do_commit ) {
                        $status = $image->move_file( $new_file ) ? -1 : 1;
                    }
                    else {
                        $status = 1;
                    }
                }
                else {
                    # Do not overwrite file.
                    $status = 2;
                }
            }
            elsif ( $cmp == 0 ) {
                # TODO: Should we remove the source, or overwrite the
                #       destination when is_forced enabled?
                # Source and Target are the same file. Nothing to do!
                $status = 2;
            }
            else {
                # TODO: Handle File::Compare error (-1).
                $status = -1
            }
        }
    }

    # Return status code.
    # FIXME: this is a work around until we implement journaling on file
    #        operations
    return ($status, $new_file);
    #return $status;
}

# Checks if the given file exists or not. First the log is checked. If there is
# no log entry for the file, the file system is checked.
#
# @param [in] $path  path of file to look for
#
# @returns  1, if file exists
#           0, otherwise
sub _does_file_exist {
    my $self = shift;
    my $path = shift;

    # If the path is logged, return the logged state.
    if ( ( my $status = $self->_get_log->does_file_exist( $path ) ) != -1 ) {
        return $status;
    }

    # If the path is not in the log it has not been moved from/to so the file
    # system contains the answer.
    return -e $path ? 1 : 0;
}

# Creates a path string by replacing parts of the location (directory) and
# file name (without extension) templates with the referenced parts of the
# supplied date and time.
#
# Both templates are optional. In place of a not specified template the
# original value, directory or filename, will be used. For example, to rename a
# file, specify only a filename template. That will make the directory resolve
# to the file's current directory and cause the file to be renamed to the name
# to file name template interpolates to.
#
# The extension in the new file name can be determined using the basename by
# extracting the substring after the last dot in the basename (default), or by
# exemining the file's embedded magic number.
#
# @param [in] self            manager object
# @param [in] image           image whose path will be assembled
# @param [in] timestamp       date and time to use for template interpolation
# @param [in] location_temp   location template (optional)
# @param [in] file_name_temp  file name temaplate (optional)
# @param [in] use_magic       determine extension using (optional)
#                             0, substring after last dot (default)
#                             1, magic number
#
# @returns the assembled path
sub _make_path {
    my $self = shift;
    my $args_ref;

    # Accept attributes in a hash or a hashref.
    if ( @_ == 1 && (ref $_[0] eq 'HASH') ) { $args_ref = shift; }
    else                                    { $args_ref = {@_};  }

    my $image          = $args_ref->{image};
    my $timestamp      = $args_ref->{timestamp};
    my $location_temp  = $args_ref->{location_temp};
    my $file_name_temp = $args_ref->{file_name_temp};
    my $use_magic      = $args_ref->{use_magic};

    # Parent directory. 
    my $new_location = ( defined $location_temp && $location_temp ne '' )
      ? $self->_expand_template( $location_temp, $timestamp )
      : $image->get_dir;

    # File name without extension.
    my $new_file_name = ( defined $file_name_temp && $file_name_temp ne '' )
      ? $self->_expand_template( $file_name_temp, $timestamp )
      : $image->get_file_name;

    # Extension.
    my $new_extension = $image->get_extension( $use_magic );

    return File::Spec->catfile(
        $new_location, $new_file_name . '.' . $new_extension
    );
}

# Expands a template by replacing special character sequences with parts of the
# specified timestamp. Non-special characters are threated as literals and left
# as is.
#
# @param [in] self       manager object
# @param [in] timestamp  whose parts will be substituted
# @param [in] template   string to expand
#
# @returns expanded string
sub _expand_template {
    my $self = shift;
    my $template = shift;
    my $timestamp = shift;

    # Return interpolated string.
    return $timestamp->strftime( $template );
}

__PACKAGE__->meta->make_immutable;

1;
