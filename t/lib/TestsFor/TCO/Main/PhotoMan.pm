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


package TestsFor::TCO::Main::PhotoMan;

use Test::Class::Most
    parent      =>'TestsFor',
    attributes  => [qw( default_manager default_files temp_dir )];
use Test::Trap;

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
# TODO: also remove the attribute
#    $self->default_manager(
#        $class->new(
#            commit => 1,
#        )
#    );

    # Instantiate default file object.
    my $src_path = File::Spec->catfile( $self->temp_dir, 'src' );
    $self->default_files([
        TCO::Image::File->new(
            path => File::Spec->catfile( $src_path, 'test.jpg' ) ),
        TCO::Image::File->new(
            path => File::Spec->catfile( $src_path, 'test2.jpg' ) ),
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
    my $res = File::Spec->catfile(
        (File::Spec->splitpath(__FILE__))[1],
        '..',
        'Image',
    );

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
        'test.jpg'  => [ $src, $src_copy ],
        'test2.jpg' => [ $src, $src_copy ],
    );
    while ( my ($file, $list) = each(%src_dst) ) {
        foreach my $dest ( @{$list} ) {
            if ( ! copy (File::Spec->catfile($res, $file), $dest) ) {
                croak "Error: while copying test file: $file -> $dest: $!";
            }
        }
    }
}

sub parse_options : Tests {
    my $self = shift;
    my %res_hash;

    # All valid options, except `--verbose', `--help' and `--man'.
    my %want = (
        touch       => 'Asia/Tokyo',
        move        => '%Y/%m.%d',
        rename      => 'img-%Y%m%d-%H%M%S',
        'use-magic' => 1,
        commit      => 1,
        force       => 1,
    );
    %res_hash = trap { TCO::Main::PhotoMan->parse_options( [map { '--' . $_ => $want{$_} } keys %want] ) };
    eq_or_diff \%res_hash, \%want, 'Valid options should be parsed correctly';

    # Invalid option.
    %res_hash = trap { TCO::Main::PhotoMan->parse_options( [qw{ --invalid }] ) };
    $trap->did_exit("an invalid option should cause the script to exit properly");
    $trap->exit_is(2, "an invalid option should cause the script to exit with 2");

    # --verbose
    %res_hash = trap { TCO::Main::PhotoMan->parse_options( [qw{ --verbose }] ) };
    is $TCO::Main::PhotoMan::is_verbose, 1, "`--verbose' should cause the global `\$is_verbose' to be set";

    # --man
    %res_hash = trap { TCO::Main::PhotoMan->parse_options( [qw{ --man }] ) };
    # FIXME: output is piped into $PAGER and not captured
    #$trap->stdout_like();
    $trap->leaveby_is('exit', "`--man' should exit properly");
    $trap->exit_is(0, "`--man' should exit with 0");

    # --help
    %res_hash = trap { TCO::Main::PhotoMan->parse_options( [qw{ --help }] ) };
    $trap->leaveby_is('exit', "`--help' should exit properly");
    $trap->exit_is(1, "`--help' should exit with 1");
}

sub check_config : Tests {
    my $self = shift;
    my %res_hash;
    my %config;

    # The argument to --rename is optional only if --use-magic is also used.
    # Also the argument should not be the empty string.
    %config = TCO::Main::PhotoMan->parse_options([ qw( --rename -- *.jpeg ) ]);
    trap { TCO::Main::PhotoMan->check_config( %config ) };
    $trap->did_die("`--rename' without paramaters should die if `--use-magic' is not specified");
    
    %config = TCO::Main::PhotoMan->parse_options([ qw( --rename --use-magic *.jpeg ) ]);
    trap { TCO::Main::PhotoMan->check_config( %config ) };
    $trap->did_return("`--rename' without parameters should return if `--use-magic' is specified");

    %config = TCO::Main::PhotoMan->parse_options([ '--rename', '', '*.jpeg' ]);
    trap { TCO::Main::PhotoMan->check_config( %config ) };
    $trap->did_die("`--rename' with empty string parameter should die");

    # Option --use-magic does not have any effect without --rename.
    %config = TCO::Main::PhotoMan->parse_options([ qw( --use-magic *.jpeg ) ]);
    trap { TCO::Main::PhotoMan->check_config( %config ) };
    $trap->did_die("`--use-magic' should die if `--rename' is not specified");

    %config = TCO::Main::PhotoMan->parse_options([ qw( --use-magic --rename -- *.jpeg ) ]);
    trap { TCO::Main::PhotoMan->check_config( %config ) };
    $trap->did_return("`--use-magic' should return if `--rename' is specified");
}

sub init_test_output {
    my $self = shift;
    $TCO::Main::PhotoMan::is_verbose = shift;

    my $fmtr = TCO::Output::Columnar::Format->new( format  => "@<\n" );

    $TCO::Main::PhotoMan::header = $fmtr;
    $TCO::Main::PhotoMan::record = $fmtr;
}

sub out_move_and_rename : Tests {
    my $self = shift;
    my $class = $self->class_to_test;

    #
    # Compact (NON-verbose) output
    #

    # Initialise output formatters.
    $self->init_test_output( 0 );

    # Parameters and expected behaviour.
    my @tests = (
        {
            in  => [ 0, 'new/path/img.jpeg' ],
            out => [ "move\nnew/path/img.jpeg\n",
                     "(compact) output should be correct when moving file" ],
        }, {
            in  => [ 1, 'new/path/img.jpeg' ],
            out => [ "over\nnew/path/img.jpeg\n",
                     "(compact) output should be correct when overwriting file" ],
        }, {
            in  => [ 2, 'new/path/img.jpeg' ],
            out => [ "same\nnew/path/img.jpeg\n",
                     "(compact) output should be correct when a copy of the same file is present at the destination" ],
        }, {
            in  => [ 3, 'new/path/img.jpeg' ],
            out => [ "there\nnew/path/img.jpeg\n",
                     "(compact) output should be correct when file is aready at destination" ],
        }
    );

    foreach my $test ( @tests) {
        trap { $class->out_move_and_rename( @{$test->{ in }} ) };
        $trap->stdout_is( @{$test->{ out }} );
    }
    
#    # Moving file.
#    trap { $class->out_move_and_rename( 0, 'new/path/file.jpeg' ) };
#    $trap->stdout_is(
#        "move\nnew/path/file.jpeg\n",
#        "output is okay",
#    );
#
#    # Overwriting file.
#    trap { $class->out_move_and_rename( 1, 'new/path/file.jpeg' ) };
#    $trap->stdout_is(
#        "over\nnew/path/file.jpeg\n",
#        "output is okay",
#    );
#
#    # A copy already there.
#    trap { $class->out_move_and_rename( 2, 'new/path/file.jpeg' ) };
#    $trap->stdout_is(
#        "same\nnew/path/file.jpeg\n",
#        "output is okay",
#    );
#
#    # File already at destination.
#    trap { $class->out_move_and_rename( 3, 'new/path/file.jpeg' ) };
#    $trap->stdout_is(
#        "there\nnew/path/file.jpeg\n",
#        "output is okay",
#    );

    # Error moving file.
    trap { $class->out_move_and_rename( -1, undef ) };
    $trap->did_die( "(compact) upon error the subroutine should die" );
    $trap->die_like( qr/MOVE:.*error/, "(compact) upon error an error message should be displayed" );
    

    #
    # Verbose output
    #

    # Initialise output formatters.
    $self->init_test_output( 1 );

    # Parameters and expected behaviour.
    my @tests = (
        {
            in  => [ 0, 'new/path/img.jpeg' ],
            out => [ "move\nmoved\nnew/path/img.jpeg\n",
                     "(verbose) output should be correct when moving file" ],
        }, {
            in  => [ 1, 'new/path/img.jpeg' ],
            out => [ "move\noverwritten\nnew/path/img.jpeg\n",
                     "(verbose) output should be correct when overwriting file" ],
        }, {
            in  => [ 2, 'new/path/img.jpeg' ],
            out => [ "move\nsame file at\nnew/path/img.jpeg\n",
                     "(verbose) output should be correct when a copy of the same file is present at the destination" ],
        }, {
            in  => [ 3, 'new/path/img.jpeg' ],
            out => [ "move\nalready at\n\n",
                     "(verbose) output should be correct when file is aready at destination" ],
        }
    );

    foreach my $test ( @tests) {
        trap { $class->out_move_and_rename( @{$test->{ in }} ) };
        $trap->stdout_is( @{$test->{ out }} );
    }
    
    # Error moving file.
    trap { $class->out_move_and_rename( -1, undef ) };
    $trap->did_die( "(verbose) upon error the subroutine should die" );
    $trap->die_like( qr/MOVE:.*error/, "(verbose) upon error an error message should be displayed" );
}

sub out_fix_timestamp : Tests {
    my $self = shift;
    my $class = $self->class_to_test;

    #
    # Compact (NON-verbose) output
    #

    # Initialise output formatters.
    $self->init_test_output( 0 );

    # Parameters and expected behaviour.
    my @tests = (
        {
            in  => [ 0, '2013:09:14 15:53:21' ],
            out => [ "2013:09:14 15:53:21\n",
                     "(compact) output should be correct when timestamp is updated successfully" ],
        }, {
            in  => [ 1 ],
            out => [ "--\n",
                     "(compact) output should be correct when timestamp is correct" ],
        }
    );

    foreach my $test ( @tests) {
        trap { $class->out_fix_timestamp( @{$test->{ in }} ) };
        $trap->stdout_is( @{$test->{ out }} );
    }

    # Error moving file.
    trap { $class->out_fix_timestamp( -1, undef ) };
    $trap->did_die( "(compact) upon error the subroutine should die" );
    $trap->die_like( qr/TOUCH:.*error/, "(compact) upon error an error message should be displayed" );


    #
    # Verbose output
    #

    # Initialise output formatters.
    $self->init_test_output( 1 );

    # Parameters and expected behaviour.
    my @tests = (
        {
            in  => [ 0, '2013:09:14 15:53:21' ],
            out => [ "time\nchanged\n2013:09:14 15:53:21\n",
                     "(verbose) output should be correct when timestamp is updated successfully" ],
        }, {
            in  => [ 1 ],
            out => [ "time\ncorrect\n\n",
                     "(verbose) output should be correct when timestamp is correct" ],
        }
    );

    foreach my $test ( @tests) {
        trap { $class->out_fix_timestamp( @{$test->{ in }} ) };
        $trap->stdout_is( @{$test->{ out }} );
    }

    # Error moving file.
    trap { $class->out_fix_timestamp( -1, undef ) };
    $trap->did_die( "(verbose) upon error the subroutine should die" );
    $trap->die_like( qr/TOUCH:.*error/, "(verbose) upon error an error message should be displayed" );
}

1;
