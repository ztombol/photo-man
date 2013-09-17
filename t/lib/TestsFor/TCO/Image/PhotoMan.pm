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
    attributes  => [qw( default_manager default_files temp_dir )];

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

    # Create sandbox. Temporary directory with a test file.
    $self->create_sandbox();
    
    # Instantiate default manager object.
    $self->default_manager(
        $class->new(
            commit => 1,
        )
    );

    # Instantiate default file object.
    my $src_path = File::Spec->catfile( $self->temp_dir, 'src' );
    $self->default_files([
        TCO::Image::File->new(
            path => File::Spec->catfile( $src_path, 'test.jpg' ) ),
        TCO::Image::File->new(
            path => File::Spec->catfile( $src_path, 'test2.jpg') ),
        TCO::Image::File->new(
            path => File::Spec->catfile( $src_path, 'no_meta.jpg') ),
    ]);
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

# Creates a temporary directory with a test file in it. The temporary directory
# will be automatically deleted when the test finishes.
sub create_sandbox {
    my $self = shift;

    # Parent of temporary directory and location of test resources,
    # respecively.
    my $tmp = '/tmp';
    my $res = (File::Spec->splitpath(__FILE__))[1];

    # Create directory structure.
    $self->temp_dir( File::Temp->newdir(
        template => "$tmp/pm-tests-XXXXXXXX",
	#CLEANUP => 0,
    ));
    my $src      = File::Spec->catdir( $self->temp_dir, 'src' );
    my $src_copy = File::Spec->catdir( $self->temp_dir, 'src_copy' );
    make_path( $src, $src_copy );

    # Copy source files.
    my %src_dst = (
        # source         # destinations
        'test.jpg'    => [ $src, $src_copy ],
        'test2.jpg'   => [ $src, $src_copy ],
        'no_meta.jpg' => [ $src ],
    );
    while ( my ($file, $list) = each(%src_dst) ) {
        foreach my $dest ( @{$list} ) {
            if ( ! copy (File::Spec->catfile($res, $file), $dest) ) {
                croak "Error: while copying test file: $file -> $dest: $!";
            }
        }
    }
}

sub constructor : Tests {
    my $self  = shift;
    my $class = $self->class_to_test;

    can_ok $class, 'new';
    lives_ok { $class->new }
        "Creating a $class with default attributes should succeed";
    isa_ok $self->default_manager, $class;
}

sub no_metadata : Tests {
    my $self = shift;
    my $file = $self->default_files->[2];
    my $man = $self->default_manager;

    # Set new timestamp.
    # TODO: remove the index after journaling is finished.
    is( ($man->fix_timestamp(
            timezone => 'Asia/Tokyo',
            image    => $file,
        ))[0], -2,
        'when DateTimeDigitized is missing, fixing file system modification timestamp should fail');
    
    # Move and rename.
    is( ($man->move_and_rename(
            image         => $file,
            location_temp => File::Spec->catfile( $self->temp_dir, 'dest/%Y.%m' ),
            filename_temp => 'img-%Y%m%d-%H%M%S',
            use_libmagic  => 1,
        ))[0], -2,
        'when DateTimeDigitised is missing, moving and renaming should fail');
}


# Test the timestamp setting subroutine. The file system timestamp should be
# changed only when the manager is in commit mode (forced mode does not affect
# this function). After a successful setting the metadata should be updated in
# the file onbject.
sub fix_timestamp : Tests {
    my $self = shift;
    my $file = $self->default_files->[0];
    my $man = $self->default_manager;

    # Set new timestamp.
    # TODO: remove the index after journaling is finished.
    is( ($man->fix_timestamp(
            timezone => 'Asia/Tokyo',
            image    => $file,
        ))[0], 0,
        'fixing file system modification timestamp should succeed');

    # Test if time stamp was correctly set.
    # TODO: remove the index after journaling is finished.
    is( ($man->fix_timestamp(
            timezone => 'Asia/Tokyo',
            image    => $file,
        ))[0], 1,
        'file system modification timestamp should be up-to-date');
}

# Test the moving and renaming subroutine. The matrix below shows what the
# desired outcomes are in different manager configurations.
#
#
#        commit   no  yes   no  yes
#        forced   no   no  yes  yes
# ----------------------------------
#          move   -/0  m/0  -/0  m/0
#        rename   -/0  m/0  -/0  m/0
# move & rename   -/0  m/0  -/0  m/0
#   src_eq_dest   -/3  -/3  -/3  -/3
#     same file   -/2  -/2  -/2  -/2
#     diff file   -/2  -/2  -/1  o/1
#
# Where the the symbol before the slash is the action performed and the one
# after is the value returned by the subroutine. The action symbols' meaning is
# the following:
#
#  - - no action taken, only status code returned
#  m - file moved and status returned
#  o - file overwritten and status returned
#
#
# The following four subroutines test the above listed cases. Each function is
# named accordint to the configuration of the manager used.
#
#   c  - commit
#   f  - forced
#   nc - no commit
#   nf - not forced
#

sub move_and_rename_nc_nf : Tests {
    my $self  = shift;
    my $man   = $self->class_to_test->new( commit => 0, forced => 0 );
    my ($op, $src_path, $dst_path);

    diag 'Manager configuration: NON-commit, NON-forced';
    
    $self->test_move_and_rename_nc( $man );
    $self->test_overwrite_itself( $man );
    $self->test_overwrite_nf( $man );

}

sub move_and_rename_c_nf : Tests {
    my $self  = shift;
    my $man   = $self->class_to_test->new( commit => 1, forced => 0 );
    my ($op, $src_path, $dst_path);
    
    diag 'Manager configuration: commit, NON-forced';

    $self->test_move_and_rename_c( $man );
    $self->test_overwrite_itself( $man );
    $self->test_overwrite_nf( $man );
}

sub move_and_rename_nc_f : Tests {
    my $self  = shift;
    my $man   = $self->class_to_test->new( commit => 0, forced => 1 );
    my ($op, $src_path, $dst_path);

    diag 'Manager configuration: NON-commit, forced';
    
    $self->test_move_and_rename_nc( $man );
    $self->test_overwrite_itself( $man );

    # Same file already at destination.
    ($op, $src_path, $dst_path) = $self->same_file_there( $man );
    ok $op == 2 && -e $src_path && -e $dst_path,
        'Attempting to overwrite the same file at the destintaion should only '
      . 'return the correct status';

    # Different file already at destination.
    ($op, $src_path, $dst_path) = $self->diff_file_there( $man );
    ok $op == 1 && -e $src_path && -e $dst_path,
        'Overwriting a different file at the destination should only return '
      . 'the correct status';
}

sub move_and_rename_c_f : Tests {
    my $self  = shift;
    my $man   = $self->class_to_test->new( commit => 1, forced => 1 );
    my ($op, $src_path, $dst_path);
    
    diag 'Manager configuration: commit, forced';
   
    $self->test_move_and_rename_c( $man );
    $self->test_overwrite_itself( $man );

    # Same file already at destination.
    ($op, $src_path, $dst_path) = $self->same_file_there( $man );
    ok $op == 2 && -e $src_path && -e $dst_path,
        'Attempting to overwrite the same file at the destintaion should only '
      . 'return the correct status';

    # Different file already at destination.
    ($op, $src_path, $dst_path) = $self->diff_file_there( $man );
    ok $op == 1 && ! -e $src_path && -e $dst_path,
        'Overwriting a different file at the destination should return the '
      . 'correct status';
}

# Move and rename related tests are extracted out into two subroutines bellow,
# as the test are identical for managers with the same commit mode regardless
# of their forced mode flag (i.e. a commit & *non-forced* mode manager requires
# the same tests as a commit & *forced* one).

# Runs:
#   - move only
#   - rename only
#   - move and rename
#
# tests for *non-commit* mode managers.
#
# @param [in] $man  manager to test
sub test_move_and_rename_nc {
    my ($self, $man) = @_;
    my ($op, $src_path, $dst_path);

    # Needs commit mode manager.
    croak 'Needs non-commit mode manager' unless ( ! $man->do_commit );

    # Move: src/test.jpg => temp/2013.03/test.jpg
    ($op, $src_path, $dst_path) = $self->move_only( $man );
    ok $op == 0 && -e $src_path && ! -e $dst_path,
        'Moving should only return the correct status';

    # Rename: temp/2013.03/test.jpg => temp/2013.03/img-20130319-160753.jpeg
    ($op, $src_path, $dst_path) = $self->rename_only( $man );
    ok $op == 0 && -e $src_path && ! -e $dst_path,
        'Renaming should only return the correct status';
    
    # Move and Rename: temp/2013.03/img-20130319-160753.jpeg => dest/2013.03/img-20130319-160753.jpeg
    ($op, $src_path, $dst_path) = $self->move_and_rename( $man );
    ok $op == 0 && -e $src_path && ! -e $dst_path,
        'Moving and renaming should only return the correct status';
}

# Runs:
#   - move only
#   - rename only
#   - move and rename
#
# tests for *commit* mode managers.
#
# @param [in] $man  manager to test
sub test_move_and_rename_c {
    my ($self, $man) = @_;
    my ($op, $src_path, $dst_path);
    
    # Needs commit mode manager.
    croak 'Needs commit mode manager' unless ( $man->do_commit );

    # Move: src/test.jpg => temp/2013.03/test.jpg
    ($op, $src_path, $dst_path) = $self->move_only( $man );
    ok $op == 0 && ! -e $src_path && -e $dst_path,
        'Moving only should preserve original filename and return the correct '
      . 'status';

    # Rename: temp/2013.03/test.jpg => temp/2013.03/img-20130319-160753.jpeg
    ($op, $src_path, $dst_path) = $self->rename_only( $man );
    ok $op == 0 && ! -e $src_path && -e $dst_path,
        'Renaming only should leave file at the same location and return the '
      . 'correct status';
    
    # Move and Rename: temp/2013.03/img-20130319-160753.jpeg => dest/2013.03/img-20130319-160753.jpeg
    ($op, $src_path, $dst_path) = $self->move_and_rename( $man );
    ok $op == 0 && ! -e $src_path && -e $dst_path,
        'Moving and renaming should work together and returnt the correct '
      . 'status';
}

# Runs overwrite test where the overwriting of the input file with itself is
# attempted. Applies to all manager configurations.
#
# @param [in] $man  manager to test
sub test_overwrite_itself {
    my ($self, $man) = @_;
    my ($op, $src_path, $dst_path);

    # Source and destination path is the same.
    ($op, $src_path, $dst_path) = $self->src_eq_dest( $man );
    ok $op == 3 && -e $src_path && -e $dst_path,
        'Attempting to overwrite a file with itself should only return the '
      . 'correct status';
}

# Runs:
#   - attempt to overwrite file with itself
#   - the same file is already at the destination
#   - a different file is already at the destination
#
# tests for non-forced mode managers.
#
# @param [in] $man  manager to test
sub test_overwrite_nf {
    my ($self, $man) = @_;
    my ($op, $src_path, $dst_path);
    
    # Needs non-forced mode manager.
    croak 'Needs non-forced mode manager' unless ( ! $man->is_forced );
    
    # Same file already at destination.
    ($op, $src_path, $dst_path) = $self->same_file_there( $man );
    ok $op == 2 && -e $src_path && -e $dst_path && compare( $src_path, $dst_path ) == 0,
        'Overwriting the same file at the destintaion should only return the '
      . 'correct status';

    # Different file already at destination.
    ($op, $src_path, $dst_path) = $self->diff_file_there( $man );
    ok $op == 2 && -e $src_path && -e $dst_path && compare( $src_path, $dst_path ) == 1,
        'Overwriting a different file at the destination should only return '
      . 'the correct status';
}

# The operations of the six individual test cases are encapsulated into
# separate subroutines below.

# Move file[0] => temp/2013.03/test.jpg
sub move_only {
    my ($self, $man) = @_;
    my $file = $self->default_files->[0];

    my $src_path = $file->get_path;
    # TODO: workaround until journaling is implemented in File::Image.
    #my $dst_path = File::Spec->catfile(
    #    $self->temp_dir, 'temp/2013.03', $file->get_basename,
    #);
    #my $op = $man->move_and_rename(
    my ($op, $dst_path) = $man->move_and_rename(
        image         => $file,
        location_temp => File::Spec->catfile( $self->temp_dir, 'temp/%Y.%m', ),
    );

    return ($op, $src_path, $dst_path);
}

# Rename file[0] => img-20130319-160753.jpeg
sub rename_only {
    my ($self, $man) = @_;
    my $file = $self->default_files->[0];

    my $src_path = $file->get_path;
    # TODO: workaround until journaling is implemented in File::Image.
    #my $dst_path = File::Spec->catfile(
    #    $file->get_dir, 'img-20130319-160753.jpeg',
    #);
    #my $op = $man->move_and_rename(
    my ($op, $dst_path) = $man->move_and_rename(
        image         => $file,
        filename_temp => 'img-%Y%m%d-%H%M%S',
        use_libmagic  => 1,
    );

    return ($op, $src_path, $dst_path);
}

# Move & Rename file[0] => dest/2013.03/img-20130319-160753.jpeg
sub move_and_rename {
    my ($self, $man) = @_;
    my $file = $self->default_files->[0];

    my $src_path = $file->get_path;
    # TODO: workaround until journaling is implemented in File::Image.
    #my $dst_path = File::Spec->catfile(
    #    $self->temp_dir, 'dest/2013.03', 'img-20130319-160753.jpeg',
    #);
    #my $op = $man->move_and_rename(
    my ($op, $dst_path) = $man->move_and_rename(
        image         => $file,
        location_temp => File::Spec->catfile( $self->temp_dir, 'dest/%Y.%m' ),
        filename_temp => 'img-%Y%m%d-%H%M%S',
        use_libmagic  => 1,
    );

    return ($op, $src_path, $dst_path);
}

# Move file[1] => src/test2.jpg
sub src_eq_dest {
    my ($self, $man) = @_;
    my $file = $self->default_files->[1];

    my $src_path = $file->get_path;
    my $dst_path = $file->get_path;
    # TODO: remove the index after journaling is finished.
    my $op = ($man->move_and_rename( image => $file ))[0];

    return ($op, $src_path, $dst_path);
}

# Move file[1] => src_copy/test2.jpg
sub same_file_there {
    my ($self, $man) = @_;
    my $file = $self->default_files->[1];

    my $src_path = $file->get_path;
    my $dst_path = File::Spec->catfile(
        $self->temp_dir, 'src_copy', $file->get_basename,
    );
    # TODO: remove the index after journaling is finished.
    my $op = ($man->move_and_rename(
        image         => $file,
        location_temp => File::Spec->catfile( $self->temp_dir, 'src_copy'),
    ))[0];

    return ($op, $src_path, $dst_path);
}

# Move and rename file[1] => src_copy/test.jpg
sub diff_file_there {
    my ($self, $man) = @_;
    my $file = $self->default_files->[1];

    my $src_path = $file->get_path;
    my $dst_path = File::Spec->catfile(
        $self->temp_dir, 'src_copy', 'test.jpg',
    );
    # TODO: remove the index after journaling is finished.
    my $op = ($man->move_and_rename(
        image         => $file,
        filename_temp => 'test',
        location_temp => File::Spec->catfile( $self->temp_dir, 'src_copy'),
    ))[0];

    return ($op, $src_path, $dst_path);
}

1;
