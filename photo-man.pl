#!/usr/bin/env perl
# 
# A simple Perl script to make a few photo library maintenance task easier on
# the Linux platform.
#
# Features:
#   * set file's last modification date to the time of digitalisation
#   * rename and move files using the digitalisation timestamp
#
# Author:  Zoltan Vass <zoltan.vass.2k6@gmail.com>
# Licence: ?
#

use strict;
use warnings;

use Carp;                   # Error reporting
use Getopt::Long;           # Option parsing
use Pod::Usage;             # Printing usage information
use File::Glob ':bsd_glob'; # Producing file names

use lib 'lib';
use TCO::Output::Columnar::Format;
use TCO::Image::File;
use TCO::Image::PhotoMan;


###############################################################################
# Default values of Options and their Arguments.
###############################################################################

my $opt_touch = 0;                  # Fix timestamp
my $arg_touch_tz = '';              # - original time zone
# FIXME: Why do we need to escape %s? \%M instead of %M.
my $opt_move = 0;                   # Move files
my $arg_move_template = undef;      # - template of new locations
# FIXME: Why do we need to escape %s? \%M instead of %M.
my $opt_rename = 0;                 # Rename files
my $arg_rename_template = undef;    # - template of new filenames

my $opt_forced = 0;                 # Execute destructive operations?
my $opt_commit = 0;                 # Make changes or do a dry-run?
my $opt_help = 0;                   # Print help
my $opt_man  = 0;                   # Print complete documentation
my $opt_verbose = 0;                # Should we print detailed output?


###############################################################################
# Parse options and check arguments
###############################################################################

# Parse options.
my $parser = Getopt::Long::Parser->new;
$parser->getoptions('touch=s' => \&handler_touch,
                    'move=s'  => \&handler_move,
                    'commit'  => \$opt_commit,
                    'force'   => \$opt_forced,
                    'verbose' => \$opt_verbose,
                    'help'    => \$opt_help,
                    'man'     => \$opt_man,) or pod2usage(2);

# Argument handlers.
sub handler_move {
    $opt_move = 1;
    my $opt_name = shift;
    $arg_move_template = shift;
}

sub handler_touch {
    $opt_touch = 1;
    my $opt_name = shift;
    $arg_touch_tz = shift;
}

# Displaying help or complete documentation.
pod2usage( -input => 'docs.pod', -verbose => 1) if $opt_help;
pod2usage( -input => 'docs.pod', -verbose => 2, -exitval => 0) if $opt_man;

# Check input files.
pod2usage( -input => 'docs.pod', -verbose => 2,
           -message => "$0: No input files are specified.") if (@ARGV == 0 && -t STDIN);

# TODO: add a step to validate configuration. magic+rename optional param etc.
#       that thing needs testing and implementation somewhere

###############################################################################
# Main
###############################################################################

# Initialise output formatters.
my ( $header, $record ) = init_output();

# Print arguments if in verbose mode. 
print_args() if $opt_verbose;

# Create Photo Manager instance.
my $pm = TCO::Image::PhotoMan->new({
    commit => $opt_commit,
    forced => $opt_forced,
});

# Processing each file.
print ":: Processing images\n";

# Print column header.
if ($opt_verbose) { }
else              { $header->print(); }

# Assemble pattern that will be used for globbing.
my $pattern = '{' . join(',', @ARGV) . '}';
while (my $file = glob("$pattern")) {
    
    # Load file.
    my $image = TCO::Image::File->new( path => $file );

    # Print file name.
    if ($opt_verbose) { $header->print( $file ); }
    else              { $record->print( $file ); }

    # Acions.
    op_move_and_rename( $pm, $image, $arg_move_template, $arg_rename_template ) if ( $opt_move );
    op_fix_timestamp( $pm, $image, $arg_touch_tz ) if ($opt_touch);

    # Print overall result of all operations.
    if ( $opt_verbose ) { }
    else                { $record->print('done'); }
}

# Print summary
if ($opt_verbose) {
    # TODO: print summary, number of moved files etc.
    #print ":: Summary\n";
}

# Warn if it was just a dry run
if (not $opt_commit) {
    print <<"WARNING";
:: Warning

!!! HEADS-UP !!!

This was just a dry-run! If you want to make the above mentioned changes
specify the `--commit' option in addition on the command line!

    \$ $0 --commit ...

WARNING
}

# Moves and/or renames a file and prints appropriate output.
#
# @param [in]     $manager        that executes the action
# @param [in,out] $image          to move and rename
# @param [in]     $location_temp  template of new location
# @param [in]     $filename_temp  template of new filename
#
# NOTE: this subroutine accesses variables from global scope!
#       $record
sub op_move_and_rename {
    my ($manager, $image, $location_temp, $filename_temp) = @_;

    # Perform action.
    my $status = $manager->move_and_rename(
        image         => $image,
        location_temp => $location_temp,
        filename_temp => $filename_temp,
    );

    # Print output.
    my $new_path = $image->get_path;
    if ( $opt_verbose ) {
        $record->print( 'move' );

          $status == 0 ? $record->print('file moved to', $new_path)
        : $status == 1 ? $record->print('file overwritten at', $new_path)
        : $status == 2 ? $record->print('same file already at', $new_path)
        : $status == 3 ? sub { $record->print("can't move to the same location");
                               $record->reset(); }
        : $status ==-1 ? croak "MOVE: error while moving file"
        :                croak "MOVE: unhandled return value $status";
    }
    else {
          $status == 0 ? $record->print('move')
        : $status == 1 ? $record->print('over')
        : $status == 2 ? $record->print('same')
        : $status == 3 ? $record->print('src=dst')
        : $status ==-1 ? croak "MOVE: error while moving file"
        :                croak "MOVE: unhandled return value $status";
    }
}

# Fixes the timestamp of a file by setting it to the `EXIF DateTimeDigitised'
# timestamp.
#
# @param [in]     $manager    that executes the action
# @param [in,out] $image      whose timestamp to fix
# @param [in]     $timezone   where the photo was taken
#
# NOTE: this subroutine accesses variables from global scope!
#       $record
sub op_fix_timestamp {
    my ($manager, $image, $timezone) = @_;

    # Set new timestamp.
    my $status = $manager->fix_timestamp(
        image    => $image,
        timezone => $timezone,
    );
    my $new_time = $image->get_fs_meta->mtime;

    # Print output.
    if ( $opt_verbose ) {
        $record->print( 'time' );

          $status == 0 ? $record->print('timestamp changed to', $new_time)
        : $status == 1 ? sub { $record->print("timestamp correct");
                               $record->reset(); }
        : $status ==-1 ? croak "MOVE: error while moving file"
        :                croak "MOVE: unhandled return value $status";
    }
    else {
          $status == 0 ? $record->print('changed')
        : $status == 1 ? $record->print('--')
        : $status ==-1 ? croak 'TOUCH: error while modifying timestamp'
        :                croak 'TOUCH: unhandled return value $status';
    }
}

###############################################################################
# Auxiliary functions
###############################################################################

# Print all relevant options and arguments passed to the script.
#
# NOTE: This functions accesses `options and arguments' in the global scope!
sub print_args {
    # Output format.
    my $out = TCO::Output::Columnar::Format->new(
        format => "@>>>>>>>>> = @<\n",
    );

    # Mode: make changes or just show what would be done.
    $out->print('mode', $opt_commit ? 'commit changes' : 'dry-run');

    # Forced: perform destructive and irreversible operations, e.g. overwriting
    # files while moving.
    $out->print('forced', $opt_forced ? 'yes' : 'no');

    # Timestamp fix.
    $out->print('time zone', $arg_touch_tz) if $opt_touch;

    # Moving/Copying photos to directories based on EXIF timestamp.
    $out->print('template', $arg_move_template) if $opt_move;
}


# Initialises output formatter objects. An array of two object are created
# depending on actions the script will execute and verbosity of the output.
#
# Normal:
#   1. column headers
#   2. filename and operation results
#
# Verbose:
#   1. filename
#   2. operation name and details. 
#
# @returns ( header, record ) output objects in this order
#
# NOTE: This function accesses `options and arguments' from global scope!
sub init_output {
    my $header;
    my $record;

    if ( $opt_verbose ) {
        # Verbose (vertical) output. Print messages on their own separate line.
        $header = TCO::Output::Columnar::Format->new( format  => ":: @<\n" );
        $record = TCO::Output::Columnar::Format->new(
            format  => "[@|||||] @>>>>>>>>>>>> = @<<<<<<<\r[@|||||]\n",
            control => "        ^             ^          ^         ",
        );
    }
    else {
        # Normal (horizontal) output. Print messages on adjecent cells on the
	# same line.

        # Base: result and filename.
        $header = TCO::Output::Columnar::Format->new(
            format  => "[result] [ filename and path                          ]",
        );
        $record = TCO::Output::Columnar::Format->new(
            format  => "[      ] @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
        );
     
        # Move.
        if ( $opt_move ) {
            $header->append( format => " [  move  ]" );
            $record->append( format => " @|||||||||" );
        }

        # Timestamp fix.
        if ( $opt_touch ) {
            $header->append( format  => " [  time  ]",
                             control => "^          " );
            $record->append( format  => " @|||||||||" );
        }

        # End of record: add line feed or overall result.
        $header->append( format => "\n" );
        $record->append( format => "\r[@|||||]\n" );
    }

    # Return output objects.
    return ( $header, $record );
}
