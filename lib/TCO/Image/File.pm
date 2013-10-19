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

use File::stat;
use File::Copy;
use File::Path qw(make_path);
use File::LibMagic;

our $VERSION = '0.2';
$VERSION = eval $VERSION;

# Path of file.
has 'path' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    reader   => 'get_path',
    writer   => '_set_path',
    trigger  => \&_trigger_path,
);

# File system metadata.
has 'fs_meta' => (
    is      => 'rw',
    isa     => 'Maybe[Object]',
    reader  => 'get_fs_meta',
    writer  => '_set_fs_meta',
    clearer => '_clear_fs_meta',
    lazy    => 1,
    builder => '_load_fs_meta',
);

# Returns file system metadata (e.g. timestamps, permissions) of the file
# specified with the currently set path.
#
# @param [in] $0  self
#
# @returns  a File::Stat object containing the file system metadata
sub _load_fs_meta {
    local $_;
    my $self = shift;
    return stat( $self->get_path );
}

# Clears metadata of file. Triggered when path is changed.
sub _trigger_path {
    my $self = shift;
    $self->_clear_meta;
}

# Clears file system metadata, so that it will get reloaded automatically when
# accessed next time.
#
# @param [in] $0  self
sub _clear_meta {
    my $self = shift;
    $self->_clear_fs_meta;
}

# Returns the basename, i.e. file name, dot and extension, of the file.
#
# @param [in] $0  self
#
# returns  basename as a string
sub get_basename {
    my $self = shift;
    return (File::Spec->splitpath( $self->get_path ))[2];
}

# Returns the file name (basename without the extension and dot).
#
# @param [in] $0  self
#
# @returns  file name without extension
sub get_file_name {
    my $self = shift;
    $self->get_path =~ m{([^/]+?).[^.]+\Z};
    return $1;
}

# Returns the extension of the file. By default and when the parameter
# evaluates to false, the extension is extracted from the basename (substring
# after last dot). If the parameter is true, the file's magic number is used to
# determine the extension.
#
# @param [in] $0  self
# @param [in] $1  use magic number to get extension?
#
# @returns  extension
sub get_extension {
    my $self = shift;
    my $use_magic = shift || 0;

    if ( $use_magic ) {
        my $magic = File::LibMagic->new();
        $magic->checktype_filename($self->get_path) =~ m{[^/]+/(.+);};
        return $1;
    }
    else {
        $self->get_path =~ /\.([^.]+)\Z/;
        return $1;
    }
}

# Returns the directory portion of the file's path.
#
# @param [in] $0  self
#
# returns  directories as a string
sub get_dir {
    my $self = shift;
    return File::Spec->canonpath( (File::Spec->splitpath( $self->get_path ))[1] );
}

# Moves the file while creating the directories leading up to the new location
# if they do not exist already. Upon success the file system will be reloaded.
#
# @param [in] $0  self
# @param [in] $1  new path of file
#
# return  0 on success
#         1 otherwise
#
# FIXME: implement this, change tests, and change photo-man.pm
# return -1 on error
#         0 otherwise
sub move_file {
    my $self = shift;
    my $dest = shift;

    # Make sure the directory tree exists up to the destination.
    make_path( (File::Spec->splitpath($dest))[1] );

    if ( move($self->get_path, $dest) ) {
        # File moved successfully. Update path and thus clear metadata.
        $self->_set_path( $dest );
        return 0;
    }

    # Error moving file.
    return -1;
}

# Returns the file's last modification time as a DateTime object.
#
# @param [in] $0  self
#
# returns  last modification time as a DateTime object
sub get_mtime {
    my $self = shift;

    # Stat successful.
    if ( defined $self->get_fs_meta ) {
        return DateTime->from_epoch(
            epoch     => $self->get_fs_meta->mtime,
            time_zone => 'local',
        );
    }

    # Could not stat file.
    return undef;
}

# Changes the file's last modification timestamp to the given time. Upon
# success the file system metadata (e.g. timestamps, permissions) will be
# reloaded.
#
# @param [in] $0  self
# @param [in] $1  new modification timestamp to set (DateTime ref)
#
# return -1 on error
#         0 on successful timestamp change
sub set_mtime {
    my $self = shift;
    my $new_time = shift;

    my $mtime = $new_time->epoch();
    my $atime = $mtime;

    # Set new timestamp.
    my $success = utime $atime, $mtime, $self->get_path();
    if ( $success ) {
        # Timestamp changed. Clear metadata.
        $self->_clear_meta;
        return 0;
    }

    # Something went wrong.
    return -1;
}

__PACKAGE__->meta->make_immutable;

1;
