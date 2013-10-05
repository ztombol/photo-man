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


package TestsFor::TCO::Image::PhotoMan;

use Test::Class::Most
    parent      =>'TestsFor',
    attributes  => [qw( default_manager test_files temp_dir )];

use TCO::Image::File;

use Carp;
use File::Temp;
use File::Path qw( make_path );
use File::Copy;
use File::Compare;
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

    # Instantiate default manager object.
    $self->default_manager(
        $class->new(
            commit => 1,
        )
    );

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

    my $src      = File::Spec->catdir( $self->temp_dir, 'src' );
    my $src_copy = File::Spec->catdir( $self->temp_dir, 'src_copy' );
    make_path( $src, $src_copy );

    # Copy test files to temp directory.
    my %src_dst = (
        # source file    # list of destinations
        'test.jpg'    => [ $src, $src_copy ],
        'test2.jpg'   => [ $src, $src_copy ],
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
    lives_ok { $class->new }
        "Creating a $class with default attributes should succeed";
    isa_ok $self->default_manager, $class;
}

# The timestamp correction subroutine's behaviour is affected by only the
# commit mode. The desired outcome is shown in the matrix below.
#
#      commit     no      yes
# ------------------------------
#         fix  - / 0,t  u / 0,t
#  up-to-date  - / 1,t  - / 1,t
#     missing  - /-2,u  - /-2,u
#       error           - /-1,j
#
# The outcome is specified as:
#     action / returned list of values
#
# Where actions:
#     - no action taken
#     u timestamp updated
#
# and return values:
#     t timestamp
#     u undef
#     j junk, unreliable data
#

# Correct timestamp in COMMIT mode.
sub fix_timestamp_c : Tests {
    my $self = shift;
    my $man = $self->default_manager;
    my ($file, @result);

    diag 'Using COMMIT mode manager';

    can_ok $man, 'fix_timestamp';

    # Success.
    $file = $self->test_files->[0];
    @result = $man->fix_timestamp(
        timezone => 'Asia/Tokyo',
        image    => $file,
    );
    $result[1] = '' . $result[1];   # Stringify timestamp.
    eq_or_diff \@result, [ 0, '2013-03-19T08:07:53' ],
        "setting new timestamp should return 0 and the new timestamp";

    $self->_timestamp_uptodate( $man );
    $self->_timestamp_error( $man );
    $self->_timestamp_missing( $man );
}

# Correct timestamp in NON-COMMIT mode.
sub fix_timestamp_nc : Tests {
    my $self = shift;
    my $man = $self->class_to_test->new( commit => 0 );
    my $file;
    my @result;

    diag 'Using NON-COMMIT mode manager';

    can_ok $man, 'fix_timestamp';

    # Success.
    $file = $self->test_files->[0];
    @result = $man->fix_timestamp(
        timezone => 'Asia/Tokyo',
        image    => $file,
    );
    $result[1] = '' . $result[1];   # Stringify timestamp.
    eq_or_diff \@result, [ 0, '2013-03-19T08:07:53' ],
        "setting new timestamp should return 0 and the new timestamp";

    # Fix timestamp before the test.
    $self->default_manager->fix_timestamp(
        timezone => 'Asia/Tokyo',
        image    => $file,
    ); 
    $self->_timestamp_uptodate( $man );

    # NOTE: We do not test for error here. In NON-COMMIT mode error can only
    #       happen if parsing the EXIF timestamp fails.

    $self->_timestamp_missing( $man );
}

# Timestamp correct.
#
# NOTE: Call after timestamp has been fixed on test_files->[0].
sub _timestamp_uptodate {
    my $self = shift;
    my $man = shift;
    my ($file, @result);
    
    $file = $self->test_files->[0];
    @result = $man->fix_timestamp(
        timezone => 'Asia/Tokyo',
        image    => $file,
    ); 
    $result[1] = '' . $result[1];   # Stringify timestamp.
    eq_or_diff \@result, [ 1, '2013-03-19T08:07:53' ],
        "attempting to set the same timestamp should return 1 and the current timestamp";

}

# Timestamp missing.
#
# NOTE: The same error happens when the timestamp is present but we failed to
#       parse it correctly. This case is less likely to happen and would hint
#       at problems in ExifTool. So we do not currently handle this situation.
sub _timestamp_missing {
    my $self = shift;
    my $man = shift;
    my ($file, @result);
    
    $file = $self->test_files->[2];
    @result = $man->fix_timestamp(
        timezone => 'Asia/Tokyo',
        image    => $file,
    ); 
    eq_or_diff \@result, [ -2, undef ],
        "attempting to correct file system timestamp when image timestamp is missing should return -2 and undef";
}

# Error setting timestamp.
sub _timestamp_error {
    my $self = shift;
    my $man = shift;
    my ($file, @result);

    # Error.
    $file = $self->test_files->[1];
    move( $file->get_path, $file->get_path . ".bak" );  # Rename the file to cause an error.
    @result = $man->fix_timestamp(
        timezone => 'Asia/Tokyo',
        image    => $file,
    ); 
    is $result[0], -1,
        "in case of error -1 should be returned (the second value is unreliable)";
}

# The move and rename subroutine's behaviour is affected by both the commit and
# the forced mode. The desired outcome is shown in the matrix below.
#
#       commit        no             yes              no             yes
#       forced        no              no             yes             yes
# ----------------------------------------------------------------------------
#         move  - / 0,p / e:n   m / 0,p / n:e   - / 0,p / e:n   m / 0,p / n:e
#       rename  - / 0,p / e:n   m / 0,p / n:e   - / 0,p / e:n   m / 0,p / n:e
#  move+rename  - / 0,p / e:n   m / 0,p / n:e   - / 0,p / e:n   m / 0,p / n:e
#   src = dest  - / 3,p / e:-   - / 3,p / e:-   - / 3,p / e:-   - / 3,p / e:-
#    same file  - / 2,p / e:e   - / 2,p / e:e   - / 2,p / e:e   - / 2,p / e:e
#    diff file  - / 2,p / e:e   - / 2,p / e:e   - / 1,p / e:e   o / 1,p / n:e
#        error  - / 0,p / -:n   - /-1,p / -:-   - / 0,p / -:n   - /-1,p / -:-
#      missing  - /-2,u / e:-   - /-2,u / e:-   - /-2,u / e:-   - /-2,u / e:-
#
# The outcome is specified as:
#     action / returned list of values / source status:destination status
#
# Where actions:
#     - no action taken
#     m file moved
#     o destination overwritten
#
# return values:
#     p new path
#     u undef
#     j junk, unreliable data
#
# and file statuses:
#     - not tested
#     e exists
#     n does not exist
#

# Move and rename in NON-COMMIT and NON-FORCED mode.
sub move_and_rename_nc_nf : Tests {
    my $self = shift;
    my $man = $self->class_to_test->new( commit => 0, forced => 0 );

    diag 'Using NON-COMMIT and NON-FORCED mode manager';
    
    $self->_test_move_and_rename_nc( $man );
    $self->_test_diff_file_nf( $man );
    $self->_test_error_nc( $man );
    $self->_test_common( $man );
}

# Move and rename in NON-COMMIT and FORCED mode.
sub move_and_rename_nc_f : Tests {
    my $self = shift;
    my $man = $self->class_to_test->new( commit => 0, forced => 1 );

    diag 'Using NON-COMMIT and FORCED mode manager';
    
    $self->_test_move_and_rename_nc( $man );
    $self->_test_diff_file_nc_f( $man );
    $self->_test_error_nc( $man );
    $self->_test_common( $man );
}

# Move and rename in COMMIT and NON-FORCED mode.
sub move_and_rename_c_nf : Tests {
    my $self = shift;
    my $man = $self->class_to_test->new( commit => 1, forced => 0 );

    diag 'Using COMMIT and NON-FORCED mode manager';
    
    $self->_test_move_and_rename_c( $man );
    $self->_test_diff_file_nf( $man );
    $self->_test_error_c( $man );
    $self->_test_common( $man );
}

# Move and rename in COMMIT and FORCED mode.
sub move_and_rename_c_f : Tests {
    my $self = shift;
    my $man = $self->class_to_test->new( commit => 1, forced => 1 );

    diag 'Using COMMIT and FORCED mode manager';
    
    $self->_test_move_and_rename_c( $man );
    $self->_test_diff_file_c_f( $man );
    $self->_test_error_c( $man );
    $self->_test_common( $man );
}

#
# Test groups.
#

# NON-COMMIT mode:
#   - move only
#   - rename only
#   - move and rename
#
# @param [in] self  test class
# @param [in] man   manager to test
sub _test_move_and_rename_nc {
    my $self = shift;
    my $man = shift;
    my ($op, $src_path, $dst_path);

    croak 'Needs NON-COMMIT mode manager' unless ( ! $man->do_commit );

    # Move [0]
    ($op, $src_path, $dst_path) = $self->_test_move_only( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ 0,   $self->temp_dir . '/moved/2013.03/test.jpg' ],
        "successful moving should return 0 and the new path";
    ok -e $src_path && ! -e $dst_path,
        "... and the file should not be moved";

    # Rename [0]
    ($op, $src_path, $dst_path) = $self->_test_rename_only( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ 0,   $self->temp_dir . '/src/renamed-20130319-160753.jpeg' ],
        "successful renaming should return 0 and the new path";
    ok -e $src_path && ! -e $dst_path,
        "... and the file should not be renamed";

    # Move and Rename [0]
    ($op, $src_path, $dst_path) = $self->_test_move_and_rename( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ 0,   $self->temp_dir . '/dest/2013.03/img-20130319-160753.jpeg' ],
        "successful moving and renaming should return 0 and the new path";
    ok -e $src_path && ! -e $dst_path,
        "... and the file should not be renamed";
}

# COMMIT mode:
#   - move only
#   - rename only
#   - move and rename
#
# @param [in] self  test class
# @param [in] man   manager to test
sub _test_move_and_rename_c {
    my $self = shift;
    my $man = shift;
    my ($op, $src_path, $dst_path);

    croak 'Needs COMMIT mode manager' unless ( $man->do_commit );

    # Move [0]
    ($op, $src_path, $dst_path) = $self->_test_move_only( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ 0,   $self->temp_dir . '/moved/2013.03/test.jpg' ],
        "successful moving should return 0 and the new path";
    ok ! -e $src_path && -e $dst_path,
        "...and the file should not be moved";

    # Rename [0]
    ($op, $src_path, $dst_path) = $self->_test_rename_only( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ 0,   $self->temp_dir . '/moved/2013.03/renamed-20130319-160753.jpeg' ],
        "successful renaming should return 0 and the new path";
    ok ! -e $src_path && -e $dst_path,
        "...and the file should not be renamed";

    # Move and Rename [0]
    ($op, $src_path, $dst_path) = $self->_test_move_and_rename( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ 0,   $self->temp_dir . '/dest/2013.03/img-20130319-160753.jpeg' ],
        "successful moving and renaming should return 0 and the new path";
    ok ! -e $src_path && -e $dst_path,
        "...and the file should not be renamed";
}

# NON-FORCED mode:
#   - a different file is already at the destination
#
# @param [in] self  test class
# @param [in] man   manager to test
sub _test_diff_file_nf {
    my $self = shift;
    my $man = shift;
    my ($op, $src_path, $dst_path);

    croak 'Needs NON-FORCED mode manager' unless ( ! $man->is_forced );

    # Move [1]
    ($op, $src_path, $dst_path) = $self->_test_diff_file( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ 2,   $self->temp_dir . '/src_copy/test.jpg' ],
        "trying to move when another file exists at the destination should return 2 and the intended path";
    ok -e $src_path && -e $dst_path,
        "... and the file should not be overwritten";
}

# NON-COMMIT and FORCED mode:
#   - a different file is already at the destination
#
# @param [in] self  test class
# @param [in] man   manager to test
sub _test_diff_file_nc_f {
    my $self = shift;
    my $man = shift;
    my ($op, $src_path, $dst_path);

    croak 'Needs NON-COMMIT and FORCED mode manager' unless ( ! $man->do_commit && $man->is_forced );

    # Move [1]
    ($op, $src_path, $dst_path) = $self->_test_diff_file( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ 1,   $self->temp_dir . '/src_copy/test.jpg' ],
        "successful overwriting of the destination should return 1 and the new path";
    ok -e $src_path && -e $dst_path,
        "... and both files should be left untouched";
}

# COMMIT and FORCED mode:
#   - a different file is already at the destination
#
# @param [in] self  test class
# @param [in] man   manager to test
sub _test_diff_file_c_f {
    my $self = shift;
    my $man = shift;
    my ($op, $src_path, $dst_path);

    croak 'Needs COMMIT and FORCED mode manager' unless ( $man->do_commit && $man->is_forced );

    # Move [1]
    ($op, $src_path, $dst_path) = $self->_test_diff_file( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ 1,   $self->temp_dir . '/src_copy/test.jpg' ],
        "successful overwriting of the destination should return 1 and the new path";
    ok ! -e $src_path && -e $dst_path,
        "... and the file should overwrite the destination";
}

# NON-COMMIT modes:
#   - error while moving
#
# @param [in] self  test class
# @param [in] man   manager to test
sub _test_error_nc {
    my $self = shift;
    my $man = shift;
    my ($op, $src_path, $dst_path);
    
    croak 'Needs NON-COMMIT mode manager' unless ( ! $man->do_commit );
    
    # Error moving [0]
    ($op, $src_path, $dst_path) = $self->_test_error( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ 0,   $self->temp_dir . '/error/2013.03/img-20130319-160753.jpg' ],
        "moving is not performed so 0 and the new path should be returned";
    # NOTE: We could/should test for the existence of the source. But currently
    #       the error is caused by renaming the file without using the tested
    #       interface.
    ok ! -e $dst_path,
        "... and nothing should be done";
}

# COMMIT modes:
#   - error while moving
#
# @param [in] self  test class
# @param [in] man   manager to test
sub _test_error_c {
    my $self = shift;
    my $man = shift;
    my ($op, $src_path, $dst_path);
    
    croak 'Needs COMMIT mode manager' unless ( $man->do_commit );

    # Error moving [0]
    ($op, $src_path, $dst_path) = $self->_test_error( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ -1,  $self->temp_dir . '/error/2013.03/img-20130319-160753.jpeg' ],
        "when an error occours in moving, -1 and the intended path should be returned";
    # NOTE: We could/should test for the existence of the source. But currently
    #       the error is caused by renaming the file without using the tested
    #       interface.
    ok ! -e $dst_path,
        "... and nothing should be done";
}

# ALL modes:
#   - source and destination path are the same
#   - the same file is already at the destination
#   - timestamp missing
#
# @param [in] self  test class
# @param [in] man   manager to test
sub _test_common {
    my $self = shift;
    my $man = shift;
    my ($op, $src_path, $dst_path);

    # Source equals destination.
    ($op, $src_path, $dst_path) = $self->_test_src_eq_dest( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ 3,   $src_path ],
        "trying to move to the current location should return 3 and the its current path";
    ok -e $src_path,
        "... and nothing should be done";
    
    # TODO: Should we change the behaviour here? Would it be more logical to
    #       remove the source/overwrite the destination?
    # A copy of the file is already at the destination.
    ($op, $src_path, $dst_path) = $self->_test_same_file( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ 2,   $self->temp_dir . '/src_copy/test2.jpg' ],
        "trying to move when a copy of the file is already at the destination should return -2 and undef";
    ok -e $src_path && -e $dst_path,
        "... and nothing should be done";

    # Timestamp missing.
    ($op, $src_path, $dst_path) = $self->_test_missing( $man );
    eq_or_diff
        [ $op, $dst_path ],
        [ -2,  undef ],
        "trying to move when the image timestamp is missing should return -2 and undef";
    ok -e $src_path,
        "... and nothing should be done";
}

#
# Single tests.
#

# Move test_files->[0] => moved/2013.03/test.jpg
sub _test_move_only {
    my $self = shift;
    my $man = shift;
    my $image = $self->test_files->[0];

    my $src_path = $image->get_path;
    my ($op, $dst_path) = $man->move_and_rename(
        image          => $image,
        location_temp  => File::Spec->catfile( $self->temp_dir, 'moved/%Y.%m', ),
    );

    return ($op, $src_path, $dst_path);
}

# Rename test_files->[0] => renamed-20130319-160753.jpeg
sub _test_rename_only {
    my $self = shift;
    my $man = shift;
    my $image = $self->test_files->[0];

    my $src_path = $image->get_path;
    my ($op, $dst_path) = $man->move_and_rename(
        image          => $image,
        file_name_temp => 'renamed-%Y%m%d-%H%M%S',
        use_magic      => 1,
    );

    return ($op, $src_path, $dst_path);
}

# Move & Rename test_files->[0] => dest/2013.03/img-20130319-160753.jpeg
sub _test_move_and_rename {
    my $self = shift;
    my $man = shift;
    my $image = $self->test_files->[0];

    my $src_path = $image->get_path;
    my ($op, $dst_path) = $man->move_and_rename(
        image          => $image,
        location_temp  => File::Spec->catfile( $self->temp_dir, 'dest/%Y.%m' ),
        file_name_temp => 'img-%Y%m%d-%H%M%S',
        use_magic      => 1,
    );

    return ($op, $src_path, $dst_path);
}

# Move test_files->[1] => test_files->[1]
sub _test_src_eq_dest {
    my $self = shift;
    my $man = shift;
    my $image = $self->test_files->[1];

    my $src_path = $image->get_path;
    my ($op, $dst_path) = $man->move_and_rename( image => $image );

    return ($op, $src_path, $dst_path);
}

# Move test_files->[1] => src_copy/test2.jpg
sub _test_same_file {
    my $self = shift;
    my $man = shift;
    my $image = $self->test_files->[1];

    my $src_path = $image->get_path;
    my ($op, $dst_path) = $man->move_and_rename(
        image          => $image,
        location_temp  => File::Spec->catfile( $self->temp_dir, 'src_copy'),
        file_name_temp => 'test2',
    );

    return ($op, $src_path, $dst_path);
}

# Move and rename file[1] => src_copy/test.jpg
sub _test_diff_file {
    my $self = shift;
    my $man = shift;
    my $image = $self->test_files->[1];

    my $src_path = $image->get_path;
    my ($op, $dst_path) = $man->move_and_rename(
        image          => $image,
        file_name_temp => 'test',
        location_temp  => File::Spec->catfile( $self->temp_dir, 'src_copy'),
    );

    return ($op, $src_path, $dst_path);
}

# Missing timestamp: test_files->[2] => -
sub _test_missing {
    my $self = shift;
    my $man = shift;
    my $image = $self->test_files->[2];

    my $src_path = $image->get_path;
    my ($op, $dst_path) = $man->move_and_rename(
        image          => $image,
        location_temp  => File::Spec->catfile( $self->temp_dir, 'dest/%Y.%m' ),
        file_name_temp => 'img-%Y%m%d-%H%M%S',
        use_magic      => 1,
    );

    return ($op, $src_path, $dst_path);
}

# Error moving: test_files->[0] => error/2013.03/img-20130319-160753.jpeg
sub _test_error {
    my $self = shift;
    my $man = shift;
    my $image = $self->test_files->[0];

    my $src_path = $image->get_path;
    move( $image->get_path, $image->get_path . ".bak" );  # Rename the file to cause an error.
    my ($op, $dst_path) = $man->move_and_rename(
        image          => $image,
        location_temp  => File::Spec->catfile( $self->temp_dir, 'error/%Y.%m' ),
        file_name_temp => 'img-%Y%m%d-%H%M%S',
        # FIXME: using libmagic on non-existent file croaks, catch it and
        #        handle it nicely.
        #use_magic      => 1,
    );

    return ($op, $src_path, $dst_path);
}

#
# Other LOW-level subroutine tests.
#

# New path assembly and (indirectly) template expansion.
sub _make_path : Tests {
    my $self = shift;
    my $man = $self->default_manager;
    my $image = $self->test_files->[0];
    my $timestamp = $image->get_timestamp( 'CreateDate' );
    my $location_temp = '%Y/%m.%d';
    my $file_name_temp = 'img-%Y%m%d-%H%M%S';
    my $path;

    # No templates. 
    $path = $man->_make_path(
        image          => $image,
        timestamp      => $timestamp,
        use_magic      => 0,
    );
    is $path, $image->get_path,
        "current path should be returned when no temaplates are specified";

    # Location template. 
    $path = $man->_make_path(
        image          => $image,
        timestamp      => $timestamp,
        location_temp  => $location_temp,
        use_magic      => 0,
    );
    is $path, '2013/03.19/test.jpg',
        "filename should be preserved when only location template is specified";

    # File name template.
    $path = $man->_make_path(
        image          => $image,
        timestamp      => $timestamp,
        file_name_temp => $file_name_temp,
        use_magic      => 0,
    );
    is $path, File::Spec->catfile( $image->get_dir, 'img-20130319-160753.jpg' ),
        "directory should be preserved when only file name template is specified";

    # Location and file name templates.
    $path = $man->_make_path(
        image          => $image,
        timestamp      => $timestamp,
        location_temp  => $location_temp,
        file_name_temp => $file_name_temp,
        use_magic      => 0,
    );
    is $path, File::Spec->catfile( '2013/03.19', 'img-20130319-160753.jpg' ),
        "path should be correct when both location and file name template are specified";
    
    # Magic.
    $path = $man->_make_path(
        image          => $image,
        timestamp      => $timestamp,
        use_magic      => 1,
    );
    is $path, File::Spec->catfile( $image->get_dir, $image->get_filename . '.jpeg' ),
        "file extension should be correctly determined by the magic number";
}

1;
