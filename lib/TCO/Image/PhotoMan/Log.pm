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


# Class keeping track of files moved with a photo manager. It does NOT record
# which file was moved where, but weather the given file exists or not.
package TCO::Image::PhotoMan::Log;

use Moose;
use MooseX::StrictConstructor;
use MooseX::FollowPBP;
use namespace::autoclean;
use Carp;

# File status. -1 unknown, 0 does not exist, 1 exists.
has 'status' => (
    is      => 'ro',
    isa     => 'HashRef[Str]',
    default => sub { {} },
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    if ( @_ != 0 ) {
        croak "Error: constructor requires no parameters!";
    }

    return $class->$orig;
};

# Records a file move in the log.
#
# @param [in] $src  source path
# @param [in] $dst  destination path
sub move {
    my $self = shift;
    my ($src, $dst) = @_;

    # Set deleted flag on source and existing on destination.
    $self->get_status->{ $src } = 0;
    $self->get_status->{ $dst } = 1;
}

# Checks existence of the given file. If log data indicates that the file
# exists, 1 is returned. If according to log data the file does not exist, 0
# is returned. If the file does not appear in the log, existence of the file
# cannot be determined and -1 is returned.
#
# @param [in] $path  file to test
#
# @returns -1, not in log
#           0, does not exist
#           1, exists
sub does_file_exist {
    my $self = shift;
    my $path = shift;

    return exists $self->get_status->{ $path } ? $self->get_status->{ $path }
                                               : -1;
}

__PACKAGE__->meta->make_immutable;

1;
