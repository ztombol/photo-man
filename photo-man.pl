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

use Getopt::Long;           # Option parsing
use Pod::Usage;             # Printing usage information
use File::Glob ':bsd_glob'; # Producing file names
use File::stat;             # Accessing filesystem metadata
use File::Copy;
use File::Path 'make_path';
use DateTime;
use DateTime::Format::Strptime;
use POSIX;
use Image::ExifTool;        # Handling photo metadata


###############################################################################
# Global variables and default values
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
my $arg_sort_template = '';

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
# Processing images
###############################################################################

# Initialise variables shared among all actions.
my $exif_tool = new Image::ExifTool;
my $local_tz = DateTime::TimeZone->new(name => 'local');
my $img_mtime_parser = DateTime::Format::Strptime->new(
    pattern   => '%Y:%m:%d %H:%M:%S',
    time_zone => $arg_touch_tz);

# Print parameters.
if ($opt_verbose) {
    my $name_w = 10;
    print ":: Parameters\n";
    printf("%*s = %s\n", $name_w, 'mode', $opt_commit ? 'commit changes' : 'dry-run');
    if ($opt_touch) {
        printf("%*s = %s\n", $name_w, 'time zone', $arg_touch_tz);
    }
    if ($opt_sort) {
        printf("%*s = %s\n", $name_w, 'template', $arg_sort_template);
    }
}

# Processing each file
print ":: Processing images\n";

# Formatting variables.
# TODO: should be encapsulated in a formatting module.
my $result_w = 6;
my $filename_w = 40;
my $touch_w = 4;
my $sort_w = 4;

# Print column header.
if (not $opt_verbose) {
    # result [filename]
    printf("%*s", $result_w, '');
    printf(" [%-*s]", $filename_w, 'filename');
    printf(" [%*s]", $touch_w, 'time') if $opt_touch;
    printf(" [%*s]", $sort_w, 'move') if $opt_sort;
    print "\n";
}

my $pattern = '{' . join(',', @ARGV) . '}';
while (my $file = glob("$pattern")) {

    # Print file name.
    if ($opt_verbose) {
        print "-- $file\n";
    }
    else {
        printf("%*s", $result_w, '[    ]');
        printf(" %-*s", $filename_w+2, $file);
    }

    # Extract metadata from image.
    my $img_meta = $exif_tool->ImageInfo("$file");

    # Set modification timestamp.
    if ($opt_touch) {
        # File system timestamp.
        my $fs_meta = stat($file);
        my $fs_mtime = DateTime->from_epoch(epoch     => $fs_meta->mtime,
                                            time_zone => $local_tz);

        # EXIF creation timestamp.
        my $img_mtime = $img_mtime_parser->parse_datetime($$img_meta{'CreateDate'});
        $img_mtime->set_formatter($img_mtime_parser);

        # Set new timestamp if needed.
        if ($img_mtime->truncate(to=>'second') ==
            $fs_mtime->truncate(to=>'second')) {

            if ($opt_verbose) {
                print "[ -- ] timestamp unchanged\n";
            }
            else {
                printf("  %*s ", $touch_w, '-- ');
            }
        }
        else {
            # Convert timestamp to local time zone. So the correct date and
            # time is stringified when we set the file system timestamp.
            $img_mtime->set_time_zone($local_tz);

            # Print timestamp.
            if ($opt_verbose) {
                print "[    ] timestamp = ", $img_mtime->strftime("%F %T %z"),
                      " (", $img_mtime->time_zone_short_name, ")";
            }
            else {
                printf("  %*s ", $touch_w, 'DONE');
            }

            # Write timestamp to file if we are not making a dry-run (default).
            if ($opt_commit) {
                $exif_tool->SetNewValue(FileModifyDate => $img_mtime,
                                        Protected      => 1);

                if (not $exif_tool->SetFileModifyDate($file)) {
                    print "\r[FAIL]\n";
                    die "ERROR: failed setting file system timestamp!\n";
                }
            }

            # Print result.
            if ($opt_verbose) {
                print "\r[DONE]\n";
            }
        }

    }

    # Sort files.
    if ($opt_sort) {
        # Construct the new filename by applying the template and appending the
        # original file extension to the result.
        my $img_mtime = $img_mtime_parser->parse_datetime($$img_meta{'CreateDate'});
        my ($ext) = $file =~ /\.([^.]+)$/;
        my $new_file = $img_mtime->strftime($arg_sort_template) . '.' . $ext;

        # Move file if current and new location are not the same.
        if ($file ne $new_file) {

            # Print new file name.
            if ($opt_verbose) {
                print "[    ] new path = $new_file";
            }
            else {
                printf("  %*s ", $sort_w, 'DONE');
            }

            # Move/Copy the file if we are not making a dry-run (default).
            if ($opt_commit) {
                # Create location if it doesn't exist yet.
                my ($nvol, $ndirs, $nfile) = File::Spec->splitpath($new_file);
                make_path $ndirs;

                # Finally, move the file.
                if (not move($file, $new_file)) {
                    print "\r[FAIL]\n";
                    die "ERROR: moving file!\n$!\n"
                }
            }

            # Print result.
            if ($opt_verbose) {
                print "\r[DONE]\n";
            }
        }
        else {
            # Target and source path+file are the same.
            if ($opt_verbose) {
                print "[ -- ] file not moved";
            }
            else {
                printf("  %*s ", $sort_w, ' -- ');
            }
        }

    }

#    {
#        foreach (keys %$img_meta) {
#            print "$_ => $$img_meta{$_}\n";
#        }
#    }

    if ($opt_verbose) {
        print "\n";
    }
    else {
        print "\r[DONE]\n";
    }
}


#
# Usage information
#

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
