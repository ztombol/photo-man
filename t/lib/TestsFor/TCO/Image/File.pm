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
    attributes  => [qw( default_file temp_dir )];

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
    $self->create_sandbox();
    
    # Instantiate default file object.
    $self->default_file(
        $class->new(
            path => File::Spec->catfile( $self->temp_dir, 'src', 'test.jpg'),
        )
    );
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
# be preserved for debugging purposes (see below).
sub create_sandbox {
    my $self = shift;

    # TODO: there has to be an easier way of locating test resources.
    # Parent of temporary directory and location of test resources,
    # respectively.
    my $tmp = '/tmp';
    my $res = (File::Spec->splitpath(__FILE__))[1];

    # Create directory structure.
    $self->temp_dir( File::Temp->newdir(
        template => "$tmp/pm-tests-XXXXXXXX",
        # Uncomment this line to preserve the temporary directory after the
        # tests finish. Useful for debugging.
        #CLEANUP => 0
    ));
    my $src = File::Spec->catdir( $self->temp_dir, 'src' );
    make_path( $src );

    # Copy source file.
    if ( ! copy (File::Spec->catfile($res, 'test.jpg'), $src) ) {
        croak "Error: while copying test file: $!";
    }
}

sub constructor : Tests {
    my $self  = shift;
    my $class = $self->class_to_test;

    can_ok $class, 'new';
    throws_ok { $class->new }
        qr/Attribute.*required/,
        "Creating a $class without proper attributes should fail";
    isa_ok $self->default_file, $class;
}

sub attributes : Tests {
    my $self = shift;
    my $file = $self->default_file;

    #
    # Attributes with non-parametrised accessors.
    #
    my %default_attributes = (
        basename  => [ 'test.jpg' ],
        filename  => [ 'test'     ],
        dir       => [ File::Spec->catfile( $self->temp_dir, 'src/' ) ],
    );
    
    while (my ($attribute, $res_and_params) = each %default_attributes) {
        my $method = "get_$attribute";
        my $result = shift @{$res_and_params};
        can_ok $file, $method;
        is $file->$method(@{$res_and_params}), $result,
            "The value for '$attribute' should be correct;"
    }

    #
    # Attributes with parametrised accessors.
    #

    # extension
    can_ok $file, 'get_extension';
    is $file->get_extension( 0 ), 'jpg',
        "'extension' should be correctly determined using the filename";
    is $file->get_extension( 1 ), 'jpeg',
        "'extension' should be correctly determined using the magic number";
    is $file->get_extension(), 'jpg',
        "'extension' by default should be extract from the filename";

    # extension
    can_ok $file, 'get_timestamp';
    is $file->get_timestamp( 'CreateDate' )
        ->set_time_zone('Europe/Budapest'),
        '2013-03-19T16:07:53',
        "'timestamp' should not have a time zone set by default";
    is $file->get_timestamp( 'CreateDate', 'Asia/Tokyo' )
        ->set_time_zone('Europe/Budapest'),
        '2013-03-19T08:07:53',
        "'timestamp' should have its time zone correctly set when one is specfied";
}

sub move_file : Tests {
    my $self = shift;
    my $file = $self->default_file;

    # Moving file to non-existent directory.
    my $new_name = 'moved.jpeg';
    my $new_path = File::Spec->catfile(
        ( $self->temp_dir, 'dest' ),
        $new_name,
    );
    ok ! $file->move_file($new_path) && -e $new_path,
        'file should be moved correctly';

    # Updated metadata after moving.
    is $file->get_img_meta->{'FileName'}, $new_name,
        'metadata should be reloaded after moving';
}

sub set_mod_time : Tests {
    my $self = shift;
    my $file = $self->default_file;

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

    # Set new time stamp.
    is $file->set_mod_time( $dt_orig ), 0,
        'changing file system timestamp should complete without errors';

    is $file->get_img_meta->{'FileModifyDate'}, $dt_local,
        'timestamp should be correctly adjusted to local time zone';
}

1;
