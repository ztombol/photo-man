#!/usr/bin/env perl
# 
# A simple Perl script to make a few photo library maintenance task easier on
# the Linux platform.
#
# Features:
#   * set file's last modification date according to the creation timestamp
#   * rename files using creation timestamp
#
# Author:  Zoltan Vass <zoltan.vass.2k6@gmail.com>
# Licence: ?
#

use strict;
use warnings;
use diagnostics;

use lib 'lib';

use TCO::Output::Columnar::Factory;
use TCO::Image::File;
use TCO::Image::PhotoMan;

use v5.14;                  # given/when
use Carp;                   # Error reporting
use Getopt::Long;           # Option parsing
use Pod::Usage;             # Printing usage information
use File::Glob ':bsd_glob'; # Producing file names


###############################################################################
# Options and arguments' default value.
###############################################################################

# Set file system's modification timestamp to the EXIF creation date. To
# determine the correct timestamp in respect to the local time zone the
# argument specifies the 'original' timezone where the photo was taken
# (Unfortunately, EXIF cannot give us this information, which is a serious
# design flaw).
my $opt_touch = 0;
my $arg_touch_tz = '';

# Move the input file(s) according to a template describing the new location.
# The template can reference parts of the creation date of the image.
# Directories are created as necessary and the filenames are preserved.
# FIXME: Why do we need to escape %s? \%M instead of %M.
my $opt_move = 0;
my $arg_move_template = '';

# Rename the input file(s) according to a template describing the new file
# name(s). The template can reference parts of the creation date of the image.
# Files are renamed but not moved.
# FIXME: Why do we need to escape %s? \%M instead of %M.
my $opt_rename = 0;
my $arg_rename_template = '';

# Force destructive operations, e.g. overwrting files in move and rename
# operations.
my $opt_forced = 0;

# If not set, do not make any changes just display what would have be done.
# Only commit the displayed changes if this flag is set to 1. By default the
# program will make a dry-run.
my $opt_commit = 0;

# Print help information.
my $opt_help = 0;

# Print the complete documentation.
my $opt_man  = 0;

# If set, the program will produce detailed output about the operations being
# done. One operation a line. If not set, only basic information is displayed.
# One operation a column. By default short output is produced.
my $opt_verbose = 0;


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
    my $image = TCO::Image::File->new({
        path => $file,
    });

    # Print file name.
    if ($opt_verbose) { $header->print( $file ); }
    else              { $record->print( $file ); }

    # Move.
    if ( $opt_move ) {
        $record->print( 'move' ) if ($opt_verbose);

        my ( $status, $new_path ) = $pm->move_and_rename({
            image         => $image,
            location_temp => $arg_move_template,
            filename_temp => undef,
        });

        # Output
        if ( $opt_verbose ) {
            # Turn of warnings to avoid messages from when/given.
            no warnings;
            for ($status) {
                $record->print('file moved to', $new_path)        when 0; 
                $record->print('file overwritten at', $new_path)  when 1;
                $record->print('same file already at', $new_path) when 2;
                when (3) {
                    $record->print("can't move to the same location");
                    $record->reset();
                }
                croak "MOVE: error while moving file" when -1;
                default { croak "MOVE: unhandled return value $status"; }
            }
        }
        else {
            # Turn of warnings to avoid messages from when/given.
            no warnings;
            for ($status) {
                $record->print('move') when 0; 
                $record->print('over') when 1;
                $record->print('same') when 2;
                $record->print('src=dst') when 3;
                croak "MOVE: error while moving file" when -1;
                default { croak "MOVE: unhandled return value $status"; }
            }
        }
    }

    # Timestamp fix.
    if ($opt_touch) {
        $record->print( 'time' ) if ($opt_verbose);

        my ( $status, $new_time ) = $pm->fix_timestamp({
            image         => $image,
            timezone      => $arg_touch_tz,
        });

        # Output
        if ( $opt_verbose ) {
            # when/given uses smartmatch which is experimental, lets switch it
            # off.
            no warnings;
            for ($status) {
                $record->print('timestamp changed to', $new_time) when 0; 
                when (1) {
                    $record->print("timestamp correct");
                    $record->reset();
                }
                croak "MOVE: error while moving file" when -1;
                default { croak "MOVE: unhandled return value $status"; }
            }
        }
        else {
            # when/given uses smartmatch which is experimental, lets switch it
            # off.
            no warnings;
            for ($status) {
                $record->print('changed') when 0; 
                $record->print('--') when 1;
                croak "TOUCH: error while modifying timestamp" when -1;
                default { croak "MOVE: unhandled return value $status"; }
            }
        }
    }

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


###############################################################################
# Auxiliary functions
###############################################################################

# NOTE: This functions accesses `options and arguments' in the global scope!
#
# Print all relevant options and arguments passed to the script.
#
# @returns    header and record output objects in this order (array)
sub print_args {
    # Output format.
    my $param = TCO::Output::Columnar::Factory->new({
        format => "@>>>>>>>>> = @<\n",
    });

    # Mode: make changes or just show what would be done.
    $param->print('mode', $opt_commit ? 'commit changes' : 'dry-run');

    # Forced: perform destructive and irreversible operations, e.g. overwriting
    # files while moving.
    $param->print('forced', $opt_forced ? 'yes' : 'no');

    # Timestamp fix.
    $param->print('time zone', $arg_touch_tz) if $opt_touch;

    # Moving/Copying photos to directories based on EXIF timestamp.
    $param->print('template', $arg_move_template) if $opt_move;
}


# NOTE: This function accesses `options and arguments' from global scope!
#
# Initialise output formatter objects. An array of two object are returned that
# are different depending on the verbosity of the output.
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
sub init_output {
    my $header;
    my $record;

    if ($opt_verbose) {
        # Verbose output (vertical). Print operations/messages on their own line.
        $header = TCO::Output::Columnar::Factory->new({
            format  => ":: @<\n",
        });
        
        $record = TCO::Output::Columnar::Factory->new({
            format  => "[@|||||] @>>>>>>>>>>>> = @<<<<<<<\r[@|||||]\n",
            control => "        ^             ^          ^           ",
        });
    }
    else {
        # Normal output (horizontal). Print operations/messages on adjecent cells
        # on the same line.

        # Base: `[result] [filename]'
        $header = TCO::Output::Columnar::Factory->new({
            format  => "[result] [ filename and path                          ]",
        });
        $record = TCO::Output::Columnar::Factory->new({
            format  => "[      ] @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
        });
     
        # Add move fix: ` [result]'
        if ( $opt_move ) {
            $header->append({ format => " [  move  ]", });
            $record->append({ format => " @|||||||||", });
        }

        # Add timestamp fix: ` [result]'
        if ( $opt_touch ) {
            $header->append({ format  => " [  time  ]",
                              control => "^          " });
            $record->append({ format => " @|||||||||", });
        }

        # End of record. Add line feed or overall result: `\r[result]\n'.
        $header->append({ format => "\n", });
        $record->append({ format => "\r[@|||||]\n", });
    }

    # Return output objects.
    return ( $header, $record );
}
