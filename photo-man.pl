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

use Getopt::Long;           # Option parsing
use Pod::Usage;             # Printing usage information
use File::Glob ':bsd_glob'; # Producing file names
use File::Find::Rule;
use File::stat;             # Accessing filesystem metadata
use File::Copy;
use File::Path 'make_path';
use DateTime;
use DateTime::Format::Strptime;
use POSIX;
use Image::ExifTool;        # Handling photo metadata
use Data::Dumper;


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

# Rename the input file(s) based on the template given as argument. The
# template can contain TODO.
my $opt_rename = 0;
my $arg_rename_template = '';

# Sort the input file(s) based on the template given as argument.
# TODO: template
my $opt_sort = 0;
my $arg_sort_op = 'copy';
my $arg_sort_template = '';

# Force destructive operations, e.g. move/copy when target exists.
my $opt_force = 0;

# If not set, do not change/move anything only display the actions that would
# be taken if we were to do it for real.
my $opt_commit = 0;

# Print help information.
my $opt_help = 'info';

# Set verbosity level.
my $opt_verbose = 0;



###############################################################################
# Parse options and check arguments
###############################################################################

# Parse options.
my $parser = Getopt::Long::Parser->new;
$parser->getoptions('touch=s' => \&handler_touch,
                    'sort:s'  => \&handler_sort,
                    'force'   => \$opt_force,
                    'commit'  => \$opt_commit,
                    'verbose' => \$opt_verbose,
                    'help'    => \$opt_help,) or pod2usage(2);

# Argument handlers.
sub handler_sort {
    $opt_sort = 1;
    ( undef, $arg_sort_template ) = @_;
}

sub handler_touch {
    $opt_touch = 1;
    ( undef, $arg_touch_tz ) = @_;
}

# Check imput files.
if (@ARGV == 0) {
    # No input files specified.
    print "Error: no input file specified!\n";
    exit;
}


###############################################################################
# Global variables
###############################################################################

# Initialise variables shared among all actions.
my $exif_tool = new Image::ExifTool;
my $local_tz = DateTime::TimeZone->new(name => 'local');
my $img_mtime_parser = DateTime::Format::Strptime->new(
    pattern   => '%Y:%m:%d %H:%M:%S',
    time_zone => $arg_touch_tz,
);

# Print arguments if in verbose mode. 
print_args() if $opt_verbose;

# Initialise output formatters.
my ( $header, $record ) = init_output();


###############################################################################
# Processing images
###############################################################################

# Processing each file.
print ":: Processing images\n";

# Print column header.
if ($opt_verbose) {
    # Verbose.
}
else {
    # Normal.
    $header->next('result');
    $header->next('filename and path');
    $header->next('time');
    $header->next('sort');
}

# Assemble pattern that will be used for globbing.
my $pattern = '{' . join(',', @ARGV) . '}';
while (my $file = glob("$pattern")) {

    # Print file name.
    if ($opt_verbose) { $header->next("$file"); }
    else { $record->next($file); }

    # Extract metadata from image.
    my $img_meta = $exif_tool->ImageInfo("$file");

    # Set modification timestamp to EXIF creation.
    touch({file => $file,
           img_meta => $img_meta,
    }) if $opt_touch;

    # Sort files.
    sort_file({file      => $file,
               img_meta  => $img_meta,
               operation => $arg_sort_op,
               forced    => $opt_force,
    }) if $opt_sort; 

    # To display all EXIF metadata, uncomment the following block.
    #foreach (keys %$img_meta) {
    #    print "$_ => $$img_meta{$_}\n";
    #}

    # Print overall result of all operations.
    if ( $opt_verbose) {
        # Nothing to do for verbose mode. Result of each operation is printed
        # at the end of the corresponding functions.
    }
    else {
        $record->next('done');
    }
}


###############################################################################
# Auxiliary functions
###############################################################################

# Print all relevant options and arguments passed to the script.
#
# NOTE: This functions accesses `options and arguments' in the global scope!
#
# @returns    header and record output objects in this order (array)
sub print_args {
    # Output format.
    my $param = TCO::Output::Columnar::Factory->new({
        format => "@>>>>>>>>> = @<\n",
        groups => "          ^      ",
    });

    # Mode: make changes or just show what would be done.
    $param->next('mode');
    $param->next( $opt_commit ? 'commit changes' : 'dry-run' );

    # Forced: perform destructive and irreversible operations, e.g. overwriting
    # files while sorting.
    $param->next('forced');
    $param->next( $opt_force ? 'yes' : 'no' );

    # Timestamp fix.
    if ($opt_touch) {
        $param->next( 'time zone' );
        $param->next( $arg_touch_tz );
    }

    # Moving/Copying photos to directories based on EXIF timestamp.
    if ($opt_sort) {
        $param->next( 'template' );
        $param->next( $arg_sort_template );
    }
}


# Initialise output by building output formatting strings and instantiating
# output handling objects. The first value returned is used for printing column
# headers in normal mode and filenames in verbose mode. The second value
# returned is for printing details of processing a single file (records).
#
# NOTE: This functions accesses `options and arguments' in the global scope!
#
# @returns    header and record output objects in this order (array)
sub init_output {
    # Assemble the formatting strings based on the options passed to the
    # script.
    my ( $header_fmt, $header_grp, $record_fmt, $record_grp );

    if ($opt_verbose) {
        # Verbose output (vertical). Print operations/messages on their own line.
        $header_fmt = ":: @<\n";
        $header_grp = "       ";
        
        $record_fmt = "[      ] @>>>>>>>>>>>> = @<<<<<<<\r[@|||||]\n";
        $record_grp = "                      ^          ^           ";
    }
    else {
        # Normal output (horizontal). Print operations/messages on adjecent cells
        # on the same line.

        # Base: `[result] [filename]'
        $header_fmt = "[@|||||] [@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<]";
        $header_grp = "        ^                                              ";
     
        $record_fmt = "[      ] @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<";
        $record_grp = "                                                       ";
        
        # Add timestamp fix: ` [result]'
        if ( $opt_touch ) {
            $header_fmt .= " [@|||||||]";
            $header_grp .= "^          ";

            $record_fmt .= " @|||||||||";
            $record_grp .= "^          ";
        }

        # Add sort fix: ` [result]'
        if ( $opt_sort ) {
            $header_fmt .= " [@|||||||]";
            $header_grp .= "^          ";

            $record_fmt .= " @|||||||||";
            $record_grp .= "^          ";
        }

        # End of record. Add line feed or overall result: `\r[result]\n'.
        $header_fmt .= "\n";
        $header_grp .= "  ";

        $record_fmt .= "\r[@|||||]\n";
        $record_grp .= "^           ";
    }

    # Initialise output.
    my $header = TCO::Output::Columnar::Factory->new({
        format => $header_fmt,
        groups => $header_grp,
    });

    my $record = TCO::Output::Columnar::Factory->new({
        format => $record_fmt,
        groups => $record_grp,
    });

    # Return output objects.
    return ( $header, $record );
}


# Sets the file system modification timestamp to the EXIF creation timestamp.
#
# @param [in] file      name of the file
# @param [in] img_meta  EXIF metadata (hash ref)
sub touch {
    my ( $args ) = @_;

    # Arguments and default values.
    my $file = $args->{file} || die "[touch]: ERROR: no file specified\n";
    my $img_meta = $args->{img_meta};

    # File system timestamp.
    my $fs_meta = stat( $file );
    my $fs_mtime = DateTime->from_epoch(
        epoch     => $fs_meta->mtime,
        time_zone => $local_tz,
    );

    # EXIF creation timestamp.
    my $img_mtime = $img_mtime_parser->parse_datetime(
        $img_meta->{'CreateDate'}
    );
    $img_mtime->set_formatter($img_mtime_parser);

    # Set new timestamp if needed.
    if ( $img_mtime->truncate( to => 'second' ) ==
        $fs_mtime->truncate( to => 'second' ) ) {

        # Timestamp is correct.
        if ( $opt_verbose ) {
            $record->next('timestamp unchanged');
            $record->skip_group();
            $record->next('--');
        }
        else {
            $record->next('--');
        }
    }
    else {
        # Convert timestamp to local time zone. So the correct date and
        # time is stringified when we set the file system timestamp.
        $img_mtime->set_time_zone($local_tz);

        # Print timestamp.
        if ($opt_verbose) {
            $record->next('timestamp');
            $record->next($img_mtime->strftime("%F %T %z") .
                   " (" . $img_mtime->time_zone_short_name . ")");
        }
        else {
            $record->next('done');
        }

        # Write timestamp to file if we are not making a dry-run (default).
        if ($opt_commit) {
            $exif_tool->SetNewValue( FileModifyDate => $img_mtime,
                                     Protected      => 1,
            );

            if ( not $exif_tool->SetFileModifyDate($file) ) {
                # Something went wrong.
                print "\r[FAIL]\n";
                die "ERROR: failed setting file system timestamp!\n";
            }
        }

        # Print result.
        if ($opt_verbose) {
            $record->next('done');
        }
    }
}


# Sort a photo. In this context, sorting means the sorting of a photo album by
# moving or copying each photo to a specified location potentially based on
# when the photos were taken. This subroutine performs interpolation on the
# sorting template and makes sure the file is moved/copied only if the target
# does not exist, is not the same as the source or overwriting the target is
# authorised.
#
# @param [in] op        operation to perform, `copy' or `move'
# @param [in] file      path of file to sort
# @param [in] img_meta  hash ref containing EXIF metadata
# @param [in] forced    force overwriting target (optional)
sub sort_file {
    my ( $args ) = @_;

    # Arguments and default values.
    my $op = $args->{operation};
    my $file = $args->{file} || die "[touch]: ERROR: no file specified\n";
    my $img_meta = $args->{img_meta};
    my $forced = $args->{forced} || 0;
    
    # Construct the new filename by applying the template and appending the
    # original file extension to the result.
    my $img_mtime = $img_mtime_parser->parse_datetime($img_meta->{'CreateDate'});
    my ( $ext ) = $file =~ /\.([^.]+)$/;
    my $new_file = $img_mtime->strftime($arg_sort_template) . '.' . $ext;
    

    # Move file if current and new location are not the same.
    if ( $file eq $new_file ) {
        # File is already at the right place (target == source).
        if ( $opt_verbose ) {
            $record->next('already sorted');
            $record->skip_group();
            $record->next('--');
        }
        else {
            $record->next('--');
        }
    }
    elsif ( -e $new_file and not $forced ) {
        # Target file already exists.
        if ( $opt_verbose ) {
            $record->next('already exists');
            $record->next( $new_file );
            $record->next('--');
        }
        else {
            $record->next('exists');
        }
    }
    else {
        # We get here if the target file either does not exist or we are
        # running in forced mode and therefore ready to overwrite target, i.e.
        # `-e _ or $forced'.

        # Perform operation if we are not doing a dry-run.
        if ($opt_commit) {
            if ( _do_sort($op, $file, $new_file) ) {
                die "[sort] ERROR: performing operation: `$op' forced: `$forced'";
            }
        }

        # Print result
        if ( not $forced ) {
            # Simplest case: target did not exist.
            if ( $opt_verbose ) {
                $record->next( $op );
                $record->next( $new_file );
                $record->next('done');
            }
            else {
                $record->next( $op );
            }
        }
        else {
            # Target was overwritten.
            if ( $opt_verbose ) {
                $record->next('overwriting');
                $record->next( $new_file );
                $record->next('done');
            }
            else {
                $record->next('overwrite');
            }
        }
    }
}


# Perform the specified `sorting' operation with the given source and target.
# For more information on what `sorting' means in this context see the
# `sort_file' subroutine.
#
# @param [in] $1  operation to perform ( move | copy )
# @param [in] $2  file to sort
# @param [in] $3  target to move/copy to
# @returns        0 on success, 1 otherwise
sub _do_sort {
    my ( $op, $file, $new_file ) = @_;

    # Make sure the directory tree leading up to the target location exists.
    my ( $nvol, $ndirs, $nfile ) = File::Spec->splitpath( $new_file );
    make_path $ndirs;

    # Perform action.
    if ($op eq 'move') {
        if ( not move($file, $new_file) ) {
            return 1;
        }
    }
    elsif ($op eq 'copy') {
        # TODO: this will mess up the timestamp, we need to:
        #   1.) do sort first and then fix the timestamp, or
        #   2.) find a way to copy while preserving metadata
	# FIXME: does not seem to copy.
	if ( not copy($file, $new_file) ) {
            return 1;
        }
    }
    else {
        # Unrecognised operation.
        die "[sort]: ERROR: unrecognised operation `$op'";
    }

    # Operation sucessfully executed.
    return 0;
}


###############################################################################
# Usage information
###############################################################################

__END__

=head1 NAME

photo-man.pl - simple photo library management script


=head1 SYNOPSIS

photo-man.pl [OPTIONS] FILE...


=head1 DESCRIPTION

photo-man is a utility to make a few photo library maintenance task easier on
the Linux platform.

It can correct the filesystem's modification timestamp by setting it to the
creation date found in the photo's EXIF metadata, which is extracted using the
Image::ExifTool module (see http://sno.phy.queensu.ca/~phil/exiftool/).

It also enables sorting large amount of photo's based on their creation time
stamp.


=head1 ARGUMENTS

The script takes one or more files as arguments. Files can be specified using
wildcard characters. The order of processing is determined by the system's
locale.

The following 


=head1 OPTIONS

Options:

--touch TIME_ZONE

Set the file system's modification timestamp to the EXIF creation timestamp.
Since EXIF can not handle time zone information, the original time zone in
which the photo was taken has to be specified by TIME_ZONE.

--verbose

Produce verbose output.


--help

display this help

=cut
