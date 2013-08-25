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
# Parse options and check arguments
###############################################################################

# Parse options.
my $parser = Getopt::Long::Parser->new;
$parser->getoptions(
    'touch=s'   => \&handler,   # Fix timestamp + original time zone
    'move=s'    => \&handler,   # Move files    + template of new location
    'rename:s'  => \&handler,   # Rename files  + template of new filename
    'use-magic' => \&handler,   # Use magic number to get extension
    'commit'    => \&handler,   # Make changes, not just a dry run
    'force'     => \&handler,   # Perform destructive operations, e.g. overwrite
    'verbose'   => \&handler,   # Print verbose output
    'help'      => \&handler,   # Display help
    'man'       => \&handler,   # Show the complete documentation
) or pod2usage(2);

my %args;
sub handler {
    my ($opt_name, $opt_arg) = @_;
    $args{$opt_name} = $opt_arg;
}

# See if we have a valid configuration.
check_config( %args );

# Displaying help or complete documentation.
pod2usage( -input => 'docs.pod', -verbose => 1) if $args{ help };
pod2usage( -input => 'docs.pod', -verbose => 2, -exitval => 0) if $args{ man };

# Check input files.
pod2usage( -input => 'docs.pod', -verbose => 2,
           -message => "$0: No input files are specified.") if (@ARGV == 0 && -t STDIN);


###############################################################################
# Main
###############################################################################

# Initialise output formatters.
my ( $header, $record ) = init_output( %args );

# Print arguments if in verbose mode. 
print_args() if $args{ verbose };

# Create Photo Manager instance.
my $pm = TCO::Image::PhotoMan->new(
    commit => $args{ commit },
    forced => $args{ forced },
);

# Processing each file.
print ":: Processing images\n";

# Print column header.
if ($args{ verbose } ) { }
else                   { $header->print(); }

# Assemble pattern that will be used for globbing.
my $pattern = '{' . join(',', @ARGV) . '}';
while (my $file = glob("$pattern")) {
    
    # Load file.
    my $image = TCO::Image::File->new( path => $file );

    # Print file name.
    if ($args{ verbose }) { $header->print( $file ); }
    else                  { $record->print( $file ); }

    # Acions.
    op_move_and_rename( $pm, $image, $args{ move }, $args{ rename } )
    	if ( $args{ move } );
    op_fix_timestamp( $pm, $image, $args{ touch } )
    	if ( $args{ touch } );

    # Print overall result of all operations.
    if ( $args{ verbose } ) { }
    else                    { $record->print('done'); }
}

# Print summary
if ($args{ verbose } ) {
    # TODO: print summary, number of moved files etc.
    #print ":: Summary\n";
}

# Warn if it was just a dry run
if (not $args{ commit }) {
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
    if ( $args{ verbose } ) {
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
    if ( $args{ verbose } ) {
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

# Validates the combination of the options and arguments passed to the script.
#
# @param [in] %args  options and their arguments
sub check_config {
    my %args = @_;

    # The argument to --rename is optional only if --use-magic is also used.
    if ( defined $args{ rename } && ! $args{ rename } && ! $args{ 'use-magic' } ) {
        die 'The --rename option requires an argument';
    }
}

# Prints all relevant options and arguments passed to the script.
#
# @param [in] %args  options and their arguments
sub print_args {
    my %args = @_;

    my $out = TCO::Output::Columnar::Format->new(
        format => "@>>>>>>>>> = @<\n",
    );

    $out->print('mode',      $args{ commit } ? 'commit changes' : 'dry-run');
    $out->print('forced',    $args{ forced } ? 'yes'            : 'no');
    $out->print('time zone', $args{ touch }) if defined $args{ touch };
    $out->print('template',  $args{ move } ) if defined $args{ move };
}

# Initialises output formatter objects. An array of two object are created
# depending on actions the script will execute and verbosity of the output.
#
#                | header         | record
# ---------------+----------------+--------------------------------
#  normal (cell) | column headers | filename and operation results
# verbose (line) | filename       | operation details
#
# @returns ( header, record ) output objects in this order
sub init_output {
    my %args = @_;

    my $header;
    my $record;

    if ( $args{ verbose } ) {
        # Verbose (vertical) output. Print messages on their own separate line.
        $header = TCO::Output::Columnar::Format->new( format  => ":: @<\n" );
        $record = TCO::Output::Columnar::Format->new(
            format  => "[@|||||] @>>>>>>>>>>>> = @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\r[@|||||]\n",
            control => "        ^             ^                                       ^         ",
        );
    }
    else {
        # Normal (horizontal) output. Print messages on adjecent cells on the
        # same line.

        # Base: result and filename.
        $header = TCO::Output::Columnar::Format->new(
            format  => "[result] [ original path                       ]",
        );
        $record = TCO::Output::Columnar::Format->new(
            format  => "[      ] @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
        );
     
        # Move and rename.
        if ( $args{ move } || $args{ rename } ) {
            $header->append( format => " [ new path                            ]" );
            $record->append( format => " @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" );
        }

        # Timestamp fix.
        if ( $args{ touch } ) {
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
