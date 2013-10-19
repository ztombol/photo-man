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


package TestsFor::TCO::Image::File;

use Test::Class::Most
    parent      =>'TestsFor',
    attributes  => [qw( test_files temp_dir )];

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

    # Create sandbox. Temporary directory with a test file.
    $self->_create_sandbox();
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

# Creates a temporary directory with test files in it. The temporary directory
# will be automatically deleted when the test finishes, unless you want it to
# be preserved for debugging purposes (see the NOTE below).
sub _create_sandbox {
    my $self = shift;
    my $class = $self->class_to_test;
    my $tmp = '/tmp';   # Parent of the temp directory.
    my $res = 't/res';  # Directory containing the test files.

    # Create directory structure.
    $self->temp_dir(
        File::Temp->newdir(
            template => "$tmp/pm-tests-XXXXXXXX",
            # NOTE: Uncomment the line below to preserve the temporary directory
            #       after the tests finish. Useful for debugging.
            #CLEANUP => 0
        )
    );

    my $src = File::Spec->catdir( $self->temp_dir, 'src' );
    make_path( $src );

    # Copy test files to temp directory.
    my %src_dst = (
        # source file    # list of destinations
        'test.jpg'    => [ $src ],
        'test2.jpg'   => [ $src ],
        'no_meta.jpg' => [ $src ],
    );

    while ( my ($file, $list) = each( %src_dst ) ) {
        foreach my $dest ( @{$list} ) {
            if ( ! copy (File::Spec->catfile( $res, $file ), $dest) ) {
                croak "Error: while copying test file: $file -> $dest: $!";
            }
        }
    }
    
    # Instantiate test file object.
    $self->test_files([
        $class->new(
            path => File::Spec->catfile( $src, 'test.jpg' ) ),
        $class->new(
            path => File::Spec->catfile( $src, 'test2.jpg') ),
        $class->new(
            path => File::Spec->catfile( $src, 'no_meta.jpg') ),
        $class->new(
            path => File::Spec->catfile( $src, 'non_existent.jpg') ),
    ]);
}

# Returns a reference to the file system metadata in a hashref.
#
# @param [in] file  file whose metadata to save
#
# @returns  hashref containing the references of metadata
sub _save_metadata_refs {
    my $self = shift;
    my $file = shift;

    return { fs_meta => $file->get_fs_meta };
}

# Tests if file system metadata is up to date, i.e. changed since it was
# recorded by `_save_metadata_refs`.
#
# @param [in] file          file whose metadata to check
# @param [in] meta_hashref  reference to the hash containing the metadata
#                           references
# @param [in] op            text to display in test description
sub _is_metadata_uptodate {
    my $self = shift;
    my ($file, $meta_hashref, $op) = @_;

    # Check file system metadata.
    isnt $file->get_fs_meta, $meta_hashref->{ fs_meta },
        "fs metadata should be reloaded after " . $op;
}

sub constructor : Tests {
    my $self  = shift;
    my $class = $self->class_to_test;

    can_ok $class, 'new';
    throws_ok { $class->new }
        qr/Attribute.*required/,
        "Creating a $class without proper attributes should fail";
    isa_ok $self->test_files->[0], $class;
}

sub path : Tests {
    my $self = shift;
    my $file  = $self->test_files->[0];
    my $file2 = $self->test_files->[1];
    my $old_meta = $self->_save_metadata_refs( $file );
    
    can_ok $file, '_set_path';
    
    # Setter.
    lives_ok { $file->_set_path( $file2->get_path ) }
        "'_set_path' should succeed";

    # Check if metadata has been reloaded. 
    $self->_is_metadata_uptodate( $file, $old_meta, 'setting path');
}

sub get_basename : Tests {
    my $self = shift;
    my $file = $self->test_files->[0];

    can_ok $file, 'get_basename';
    is $file->get_basename, 'test.jpg',
        "file name with extension should be returned correctly";
}

sub get_file_name : Tests {
    my $self = shift;
    my $file = $self->test_files->[0];

    can_ok $file, 'get_file_name';
    is $file->get_file_name, 'test',
        "file name without extension should be returned correctly";
}

sub get_extension : Tests {
    my $self = shift;
    my $file = $self->test_files->[0];

    can_ok $file, 'get_extension';
    is $file->get_extension, 'jpg',
        "extension should be extracted from basename by default";
    is $file->get_extension( 0 ), 'jpg',
        "extension should be correctly extracted from the basename";
    is $file->get_extension( 1 ), 'jpeg',
        "extension should be correctly determined from the magic number";
}

sub get_dir : Tests {
    my $self = shift;
    my $file = $self->test_files->[0];

    can_ok $file, 'get_dir';
    is $file->get_dir, File::Spec->catdir( $self->temp_dir, 'src' ),
        "directory portion of the path should be returned correctly";
}

sub move_file : Tests {
    my $self = shift;
    my $file = $self->test_files->[0];
    my $old_meta = $self->_save_metadata_refs( $file );
    my $new_path;

    can_ok $file, 'move_file';
    
    # Moving file to non-existent directory.
    $new_path = File::Spec->catfile( $self->temp_dir, 'src', 'moved.jpg' );
    is $file->move_file($new_path) == 0 && -e $new_path, 1,
        "file should be moved correctly to an existing directory";

    # Moving file to non-existent directory.
    $new_path = File::Spec->catfile( $self->temp_dir, 'dest', 'moved.jpg' );
    is $file->move_file($new_path) == 0 && -e $new_path, 1,
        "file should be moved correctly to a non-existing folder";
    
    # Check if metadata has been reloaded. 
    $self->_is_metadata_uptodate( $file, $old_meta, 'moving file');

    # Error moving file.
    $new_path = File::Spec->catfile( '/usr/bin/moved.jpg' );
    is $file->move_file($new_path) == -1 && ! -e $new_path, 1,
        "error while moving should be reported correctly";
}

sub get_mtime : Tests {
    my $self = shift;
    my $file = $self->test_files->[0];
    my $file2 = $self->test_files->[3];

    can_ok $file, 'get_mtime';

    # Success.
    my $want = DateTime->from_epoch( epoch => $file->get_fs_meta->mtime );
    is $file->get_mtime, $want,
        "modification time should be returned correctly";
    
    # Cannot stat file.
    is $file2->get_mtime, undef,
        "undef should be returned when file system metadata is not available";
}

sub set_mtime : Tests {
    my $self = shift;
    my $file = $self->test_files->[0];
    my $old_meta_refs = $self->_save_metadata_refs( $file );

    can_ok $file, 'set_mtime';

    # New time stamp in original time zone.
    my $dt_orig = DateTime->new(
        year      => 2013,
        month     => 8,
        day       => 9,
        hour      => 19,
        minute    => 55,
        second    => 17,
        time_zone => 'Asia/Tokyo',
    );

    # New time stamp in local time zone.
    my $dt_local = $dt_orig->clone();
    $dt_local->set_time_zone( 'local' );

    # Set new time stamp.
    is $file->set_mtime( $dt_orig ), 0,
        'changing file system timestamp should succeed';

    my $dt_set = DateTime->from_epoch( epoch => $file->get_fs_meta->mtime );
    is $dt_set, $dt_local,
        'timestamp should be converted into local time zone';

    # Check if metadata has been reloaded. 
    $self->_is_metadata_uptodate( $file, $old_meta_refs, 'setting modification timestamp' );
}

1;
