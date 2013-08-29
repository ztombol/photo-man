#!/usr/bin/env perl

#
# photo-man is a simple command line utility automating common photo library
# management tasks, such as:
#   - moving and renaming based on EXIF DateTimeDigitized timestamp
#   - setting file system modificaion timestamp to EXIF DateTimeDigitized
#
# For a complete list of features see the documentation by issuing
# `photo-man --man'.
#
# photo-man, including test assests such as image files, and its documentation
# is licenced under GPL version 3.
#
# Authors: Zoltan Vass <Zoltan Vass <zoltan.tombol (at) gmail (dot) com>
#


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

# Print and then see if we have a valid configuration.
print_config( %args );
check_config( %args );

# Displaying help or complete documentation.
pod2usage( -input => 'photo-man.pod', -verbose => 1) if $args{ help };
pod2usage( -input => 'photo-man.pod', -verbose => 2, -exitval => 0) if $args{ man };

# Check input files.
pod2usage( -input => 'photo-man.pod', -verbose => 1,
           -message => "$0: No input files specified.") if (@ARGV == 0 && -t STDIN);


###############################################################################
# Main
###############################################################################

# Initialise output formatters.
my ( $header, $record ) = init_output( %args );

# Create Photo Manager instance.
my $pm = TCO::Image::PhotoMan->new(
    commit => $args{ commit },
    forced => $args{ forced },
);

# Processing each file.
print ":: Processing images\n";

# Print column header.
if ( $args{ verbose } ) { }
else                    { $header->print(); }

# Assemble pattern that will be used for globbing.
my $pattern = '{' . join(',', @ARGV) . '}';
while (my $file = glob("$pattern")) {
    
    # Load file.
    my $image = TCO::Image::File->new( path => $file );

    # Print file name.
    if ($args{ verbose }) { $header->print( $file ); }
    else                  { $record->print( $file ); }

    # Acions.
    op_move_and_rename( $pm, $image, $args{ move }, $args{ rename },
            $args{'use-magic'} )
    	if ( defined $args{ move } || defined $args{ rename } );
    op_fix_timestamp( $pm, $image, $args{ touch } )
    	if ( defined $args{ touch } );

    # Print overall result of all operations.
    if ( $args{ verbose } ) { print "\n"; }
    else                    { $record->print('done'); }
}

# Print summary
print ":: Summary\n";

# TODO: print summary, number of moved files etc.

# Warn if it was just a dry run
if (not $args{ commit }) {
    print <<"WARNING";

!!! HEADS-UP !!!

This was just a dry-run! If you want to make the changes above add `--commit'
to your command!

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
    my ($manager, $image, $location_temp, $filename_temp, $use_libmagic) = @_;

    # Perform action.
    # FIXME: this is a work around of getting results in dry-run, will be
    #        removeduntil after Image::File implements implement journaling
    #        support
    my ($status, $new_path) = $manager->move_and_rename(
    #my $status = $manager->move_and_rename(
        image         => $image,
        location_temp => $location_temp,
        filename_temp => $filename_temp,
        use_libmagic  => $use_libmagic,
    );
    #my $new_path = $image->get_path;

    # Print output.
    if ( $args{ verbose } ) {
        $record->print( 'move' );

          $status == 0 ? $record->print('moved', $new_path)
        : $status == 1 ? $record->print('overwritten', $new_path)
        : $status == 2 ? $record->print('same file at', $new_path)
        : $status == 3 ? sub { $record->print("already at");
                               $record->reset(); }->()
        : $status ==-1 ? croak "MOVE: error while moving file"
        :                croak "MOVE: unhandled return value $status";
    }
    else {
          $status == 0 ? $record->print('move')
        : $status == 1 ? $record->print('over')
        : $status == 2 ? $record->print('same')
        : $status == 3 ? $record->print('there')
        : $status ==-1 ? croak "MOVE: error while moving file"
        :                croak "MOVE: unhandled return value $status";
        $record->print( $new_path );
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
    # FIXME: this is a work around until we implement journaling on file
    #        operations
    my ($status, $new_time) = $manager->fix_timestamp(
    #my $status = $manager->fix_timestamp(
        image    => $image,
        timezone => $timezone,
    );
    #my $new_time = $image->get_fs_meta->mtime;

    # Print output.
    if ( $args{ verbose } ) {
        $record->print( 'time' );

          $status == 0 ? $record->print('changed', $new_time)
        : $status == 1 ? sub { $record->print("correct");
                               $record->reset(); }->()
        : $status ==-1 ? croak "MOVE: error while moving file"
        :                croak "MOVE: unhandled return value $status";
    }
    else {
          $status == 0 ? $record->print( $new_time )
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
    if ( defined $args{ rename } && $args{ rename } eq '' && ! $args{ 'use-magic' } ) {
        die 'The --rename option requires an argument';
    }
    
    # Option --use-magic does not have any effect without --rename.
    if ( ! defined $args{ rename } && $args{ 'use-magic' } ) {
        die 'The --use-magic option can only be used together with --rename.';
    }
}

# Prints all relevant options and arguments passed to the script.
#
# @param [in] %args  options and their arguments
sub print_config {
    my %args = @_;

    print ":: Configuration\n";
    my $out = TCO::Output::Columnar::Format->new(
        format => "@>>>>>>>>> = @<\n",
    );

    # Always.
    $out->print('mode',   $args{ commit } ? 'commit changes' : 'dry-run');
    $out->print('forced', $args{ forced } ? 'yes'            : 'no');

    # Timestamp fixing.
    $out->print('time zone', $args{ touch } ) if defined $args{ touch };

    # Move and/or rename.
    $out->print('location',  $args{ move }  ) if defined $args{ move };
    $out->print('file name', $args{ rename } ne '' ? $args{ rename }
            : "< original >")
        if defined $args{ rename };
    $out->print('magic',     $args{'use-magic'} ? 'yes' : 'no')
        if defined $args{ rename };

    print "\n";
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

    my ($header, $record);

    if ( $args{ verbose } ) {
        # Verbose (vertical) output. Print messages on their own separate line.
        $header = TCO::Output::Columnar::Format->new( format  => "@<\n" );
        $record = TCO::Output::Columnar::Format->new(
            format  => "[@|||||] @>>>>>>>>>>>> > @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n",
            control => "        ^             ^                                        ",
        );
    }
    else {
        # Normal (horizontal) output. Print messages on adjecent cells on the
        # same line.

        # Base: result and filename.
        $header = TCO::Output::Columnar::Format->new(
            # This is SHORTER by ONE character so we can have a different
            # trailing character depending if move/rename is specified or not.
            #
            #          v---------- complete length ----------v
            format  => "[result] [ file                     "
                    . ( (defined $args{move} || defined $args{rename})
                    ? " " : "]" ),
        );
        $record = TCO::Output::Columnar::Format->new(
            format  => "[      ] @<<<<<<<<<<<<<<<<<<<<<<<<<<<",
        );
     
        # Move and rename.
        if ( defined $args{ move } || defined $args{ rename } ) {
            $header->append( format => " > action > new path                   ]" );
            $record->append( format => " >@|||||||> @<<<<<<<<<<<<<<<<<<<<<<<<<<<" );
        }

        # Timestamp fix.
        if ( defined $args{ touch } ) {
            $header->append( format  => " [    timestamp    ]" );
            $record->append( format  => " @||||||||||||||||||" );
        }

        # End of record: add line feed or overall result.
        $header->append( format => "\n" );
        $record->append( format => "\r[@|||||]\n" );
    }

    # Return output objects.
    return ( $header, $record );
}
