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


package TestsFor::TCO::Image::File::Image;

use Test::Class::Most
    parent      =>'TestsFor::TCO::Image::File';

use Carp;
use File::Temp;
use File::Path qw( make_path );
use File::Copy;
use DateTime;
use DateTime::Format::Strptime;

sub startup : Tests(startup) {
    my $self  = shift;
    my $class = ref $self;

    # First call the parent method.
    $self->next::method;

    # Startup code goes here...
}

sub setup : Tests(setup) {
    my $self  = shift;
    my $class = $self->class_to_test;

    # First call the parent method.
    $self->next::method;

    # Setup code goes here...
}

sub teardown : Tests(teardown) {
    my $self = shift;

    # Teardown code goes here...

    # Finally, call parent method.
    $self->next::method;
}

sub shutdown : Tests(shutdown) {
    my $self = shift;

    # Shutdown code goes here...

    # Finally, call parent method.
    $self->next::method;
}

# Returns a reference to the file system metadata in a hashref.
#
# @param [in] file  file whose metadata to save
#
# @returns  hashref containing the 
sub _save_metadata_refs {
    my $self = shift;
    my $file = shift;

    # Save reference to file system metadata.
    my $meta_hashref = $self->next::method( $file );

    # Save reference to image metadata.
    $meta_hashref->{ img_meta } = $file->get_img_meta;
   
    return $meta_hashref;
}

# Tests if file system and image metadata is up to date, i.e. changed since it
# was recorded by `_save_metadata_refs`.
#
# @param [in] file          file whose metadata to check
# @param [in] meta_hashref  reference to the hash containing the metadata
#                           references
# @param [in] op            text to display in test description
sub _is_metadata_uptodate {
    my $self = shift;
    my ($file, $meta_hashref, $op) = @_;

    # Check file system metadata.
    $self->next::method( $file, $meta_hashref, $op );

    # Check image metadata.
    isnt $file->get_img_meta, $meta_hashref->{ img_meta },
        "image metadata should be reloaded after " . $op;
}

sub get_exif_digitized : Tests {
    my $self = shift;
    my $file  = $self->test_files->[0];
    my $file2 = $self->test_files->[2];
    my $dt;

    can_ok $file, 'get_exif_digitized';

    # Success.
    $dt = $file->get_exif_digitized;
    is $dt, '2013-03-19T16:07:53',
        "timestamp should be returned correctly";
    
    # Missing timestamp.
    $dt = $file2->get_exif_digitized;
    is $dt, undef,
        "undef should be returned if timestamp is missing from metadata";
}

1;
