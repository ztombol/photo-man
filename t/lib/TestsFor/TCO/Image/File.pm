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
        TCO::Image::File->new(
            path => File::Spec->catfile( $src, 'test.jpg' ) ),
        TCO::Image::File->new(
            path => File::Spec->catfile( $src, 'test2.jpg') ),
        TCO::Image::File->new(
            path => File::Spec->catfile( $src, 'no_meta.jpg') ),
    ]);
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
    
    can_ok $file, '_set_path';
    
    my $old_fs_meta = $file->get_fs_meta;
    my $old_img_meta = $file->get_img_meta;

    # Setter.
    lives_ok { $file->_set_path( $file2->get_path ) }
        "'set_path' should succeed";

    # Updated metadata after moving.
    $self->_metadata_updated( $file, $old_fs_meta, $old_img_meta, 'setting path');
}

sub get_basename : Tests {
    my $self = shift;
    my $file = $self->test_files->[0];

    can_ok $file, 'get_basename';
    is $file->get_basename, 'test.jpg',
        "filename with extension should be returned correctly";
}

sub get_filename : Tests {
    my $self = shift;
    my $file = $self->test_files->[0];

    can_ok $file, 'get_filename';
    is $file->get_filename, 'test',
        "filename without extension should be returned correctly";
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

sub get_timestamp : Tests {
    my $self = shift;
    my $file = $self->test_files->[0];

    can_ok $file, 'get_timestamp';
    is $file->get_timestamp( 'CreateDate' )
        ->set_time_zone('Europe/Budapest'),
        '2013-03-19T16:07:53',
        "a timestamp should have 'floating' time zone set by default";
    is $file->get_timestamp( 'CreateDate', 'Asia/Tokyo' )
        ->set_time_zone('Europe/Budapest'),
        '2013-03-19T08:07:53',
        "a timestamp should have its time zone correctly set when one is specfied";
}

sub move_file : Tests {
    my $self = shift;
    my $file = $self->test_files->[0];
    my $new_path;

    can_ok $file, 'move_file';
    
    # Moving file to non-existent directory.
    $new_path = File::Spec->catfile( $self->temp_dir, 'src', 'moved.jpg' );
    ok ! $file->move_file($new_path) && -e $new_path,
        "file should be moved correctly to an existing directory";

    my $old_fs_meta = $file->get_fs_meta;
    my $old_img_meta = $file->get_img_meta;

    # Moving file to non-existent directory.
    $new_path = File::Spec->catfile( $self->temp_dir, 'dest', 'moved.jpg' );
    ok ! $file->move_file($new_path) && -e $new_path,
        "file should be moved correctly to a non-existing folder";
    
    $self->_metadata_updated( $file, $old_fs_meta, $old_img_meta, 'setting timestamp');
}

sub set_mod_time : Tests {
    my $self = shift;
    my $file = $self->test_files->[0];

    can_ok $file, 'set_mod_time';

    # New time stamp.
    my $new_mtime = DateTime->new(
        year      => 2013,
        month     => 8,
        day       => 9,
        hour      => 19,
        minute    => 55,
        second    => 17,
        time_zone => 'Asia/Tokyo',
        formatter => DateTime::Format::Strptime->new(
            pattern => '%Y:%m:%d %H:%M:%S%z'
        ),
    );

    # Time stamp in original and local time zones.
    (my $dt_orig = $new_mtime) =~ s/(\d\d)\Z/:$1/;
    $new_mtime->set_time_zone( 'local' );
    (my $dt_local = $new_mtime) =~ s/(\d\d)\Z/:$1/;
    
    my $old_fs_meta = $file->get_fs_meta;
    my $old_img_meta = $file->get_img_meta;

    # Set new time stamp.
    is $file->set_mod_time( $dt_orig ), 0,
        'changing file system timestamp should succeed';
    is $file->get_img_meta->{ FileModifyDate }, $dt_local,
        'timestamp should be converted into local time zone';
    
    $self->_metadata_updated( $file, $old_fs_meta, $old_img_meta, 'setting timestamp');
}

sub _metadata_updated {
    my $self = shift;
    my ($file, $old_fs_meta, $old_img_meta, $op) = @_;

    # Updated metadata after moving.
    isnt $file->get_fs_meta, $old_fs_meta,
        "fs metadata should be reloaded after " . $op;
    isnt $file->get_img_meta, $old_img_meta,
        "image metadata should be reloaded after " . $op;
}

1;
