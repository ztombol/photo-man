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
    parent      =>'TestsFor';
use Test::Trap;

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

sub parse_options : Tests {
    my $self = shift;
    my %res_hash;

    # Options that modify %args, i.e. all except `--verbose', `--help' and `--man'.
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

    # Suppress 'Name "xyz" used only once: possible typo' warning.
    $TCO::Main::PhotoMan::header = $TCO::Main::PhotoMan::record;

    # Simple (shared) test formatter.
    my $fmtr = TCO::Output::Columnar::Format->new( format  => "@<\n" );
    $TCO::Main::PhotoMan::header = $fmtr;
    $TCO::Main::PhotoMan::record = $fmtr;
}

sub out_move_and_rename : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my @tests;
    
    diag "Compat (non-verbose) output";

    # Initialise output formatters.
    $self->init_test_output( 0 );

    # Parameters and expected (non-fatal) behaviour.
    @tests = (
        {
            in  => [ 0, 'new/path/img.jpeg' ],
            out => [ "move\nnew/path/img.jpeg\n",
                     "output should be correct when moving file" ],
        }, {
            in  => [ 1, 'new/path/img.jpeg' ],
            out => [ "over\nnew/path/img.jpeg\n",
                     "output should be correct when overwriting file" ],
        }, {
            in  => [ 2, 'new/path/img.jpeg' ],
            out => [ "same\nnew/path/img.jpeg\n",
                     "output should be correct when a copy of the same file is present at the destination" ],
        }, {
            in  => [ 3, 'new/path/img.jpeg' ],
            out => [ "there\nnew/path/img.jpeg\n",
                     "output should be correct when file is aready at destination" ],
        }, {
            in  => [-2, undef ],
            out => [ "error!\nmissing timestamp\n",
                     "output should be correct when DateTimeDigitized is missing from metadata" ],
        }
    );
    foreach my $test ( @tests) {
        trap { $class->out_move_and_rename( @{$test->{ in }} ) };
        $trap->stdout_is( @{$test->{ out }} );
    }
    
    # Error moving file.
    trap { $class->out_move_and_rename( -1, undef ) };
    $trap->did_die( "upon error the subroutine should die" );
    $trap->die_like( qr/MOVE:.*error/, "upon error an error message should be displayed" );
    

    diag "Verbose output";

    # Initialise output formatters.
    $self->init_test_output( 1 );

    # Parameters and expected (non-fatal) behaviour.
    @tests = (
        {
            in  => [ 0, 'new/path/img.jpeg' ],
            out => [ "move\nmoved\nnew/path/img.jpeg\n",
                     "output should be correct when moving file" ],
        }, {
            in  => [ 1, 'new/path/img.jpeg' ],
            out => [ "move\noverwritten\nnew/path/img.jpeg\n",
                     "output should be correct when overwriting file" ],
        }, {
            in  => [ 2, 'new/path/img.jpeg' ],
            out => [ "move\nsame file at\nnew/path/img.jpeg\n",
                     "output should be correct when a copy of the same file is present at the destination" ],
        }, {
            in  => [ 3, 'new/path/img.jpeg' ],
            out => [ "move\nalready at\n\n",
                     "output should be correct when file is aready at destination" ],
        }, {
            in  => [-2 ],
            out => [ "move\nerror!\nmissing timestamp\n",
                     "output should be correct when DateTimeDigitized is missing from metadata" ],
        }
    );
    foreach my $test ( @tests) {
        trap { $class->out_move_and_rename( @{$test->{ in }} ) };
        $trap->stdout_is( @{$test->{ out }} );
    }
    
    # Error moving file.
    trap { $class->out_move_and_rename( -1, undef ) };
    $trap->did_die( "upon error the subroutine should die" );
    $trap->die_like( qr/MOVE:.*error/, "upon error an error message should be displayed" );
}

sub out_fix_timestamp : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my @tests;
    my $new_time = DateTime->new(
        year   => 2013, month  => 9,  day    => 14,
        hour   => 15,   minute => 53, second => 21,
    );

    diag "Compat (non-verbose) output";

    # Initialise output formatters.
    $self->init_test_output( 0 );

    # Parameters and expected (non-fatal) behaviour.
    @tests = (
        {
            in  => [ 0, $new_time ],
            out => [ "2013:09:14 15:53:21\n",
                     "output should be correct when timestamp is updated successfully" ],
        }, {
            in  => [ 1 ],
            out => [ "--\n",
                     "output should be correct when timestamp is correct" ],
        }, {
            in  => [-2 ],
            out => [ "!!! missing !!!\n",
                     "output should be correct when DateTimeDigitized is missing from metadata" ],
        }
    );
    foreach my $test ( @tests) {
        trap { $class->out_fix_timestamp( @{$test->{ in }} ) };
        $trap->stdout_is( @{$test->{ out }} );
    }

    # Error moving file.
    trap { $class->out_fix_timestamp( -1, undef ) };
    $trap->did_die( "upon error the subroutine should die" );
    $trap->die_like( qr/TOUCH:.*error/, "upon error an error message should be displayed" );


    diag "Verbose output";

    # Initialise output formatters.
    $self->init_test_output( 1 );

    # Parameters and expected (non-fatal) behaviour.
    @tests = (
        {
            in  => [ 0, $new_time ],
            out => [ "time\nchanged\n2013:09:14 15:53:21\n",
                     "output should be correct when timestamp is updated successfully" ],
        }, {
            in  => [ 1 ],
            out => [ "time\ncorrect\n\n",
                     "output should be correct when timestamp is correct" ],
        }, {
            in  => [-2 ],
            out => [ "time\nerror!\nmissing timestamp\n",
                     "output should be correct when DateTimeDigitized is missing from metadata" ],
        }
    );
    foreach my $test ( @tests) {
        trap { $class->out_fix_timestamp( @{$test->{ in }} ) };
        $trap->stdout_is( @{$test->{ out }} );
    }

    # Error moving file.
    trap { $class->out_fix_timestamp( -1, undef ) };
    $trap->did_die( "upon error the subroutine should die" );
    $trap->die_like( qr/TOUCH:.*error/, "upon error an error message should be displayed" );
}

1;
