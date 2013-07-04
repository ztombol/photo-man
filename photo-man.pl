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
use File::Basename;
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
# template can contain 
my $opt_rename = 0;
my $arg_rename_template = '';

# Print help information.
my $opt_help = 0;

# Set verbosity level.
my $opt_log_level = 0;



###############################################################################
# Parse options and check arguments
###############################################################################

# Parse options.
my $parser = Getopt::Long::Parser->new;
$parser->getoptions('touch=s'  => \&handler_touch,
                    'rename:s' => \&handler_rename,
                    'verbose+' => \$opt_log_level,
                    'help'     => \$opt_help,) or pod2usage(2);

# OPTION: rename
sub handler_rename {
    $opt_rename = 1;
    ( undef, $arg_rename_template ) = @_;
}

# OPTION: touch
sub handler_touch {
    $opt_touch = 1;
    ( undef, $arg_touch_tz ) = @_;
}

# Check arguments.
if (@ARGV == 0) {
    # No input files specified.
    print "Error: no input file specified!\n";
    exit;
}


###############################################################################
# Processing images
###############################################################################

# Print details of processing.
#if (1) {
#print <<DET;
#:: Parameters
#  template = $arg_rename_template
# time zone = $arg_touch_tz
#DET
#}

# Processing each file
print ":: Processing images\n";
my $exif_tool = new Image::ExifTool;

my $pattern = '{' . join(',', @ARGV) . '}';
while (my $file = glob("$pattern")) {
    print "[    ] $file ";
#    print "\n";

    # Extract metadata from image.
    my $img_meta = $exif_tool->ImageInfo("$file");

    # Set modification timestamp.
    if ($opt_touch) {
        # File system timestamp.
        my $fs_meta = stat($file);
        my $fs_mtime = DateTime->from_epoch(epoch     => $fs_meta->mtime,
                                            time_zone => 'local');

        # Print timestamp.
        for ($fs_mtime->time_zone, 'UTC') {
            $fs_mtime->set_time_zone($_);
#            print "fs  = [ ", $fs_mtime->time_zone_short_name, " ] ", $fs_mtime->strftime("%F %T %z"), "\n";
        }

        # EXIF creation timestamp.
        my $parser = DateTime::Format::Strptime->new(
            pattern => '%Y:%m:%d %H:%M:%S');
        my $img_mtime = $parser->parse_datetime( $$img_meta{'CreateDate'} );
        $img_mtime->set_time_zone($arg_touch_tz);

        # Print timestamp.
        for ($img_mtime->time_zone, 'UTC') {
            $img_mtime->set_time_zone($_);
#            print "img = [ ", $img_mtime->time_zone_short_name, " ] ", $img_mtime->strftime("%F %T %z"), "\n";
        }

#        print "-----\n";

        # Compare UTC timestamps.
        if ($img_mtime->truncate(to=>'second') ==
            $fs_mtime->truncate(to=>'second')) {
#            print "date OK; nothing to do\n";
        }
        else {
            # Print timestamp.
            for ('local', $arg_touch_tz, 'UTC') {
                $img_mtime->set_time_zone($_);
#                print "new = [ ", $img_mtime->time_zone_short_name, " ] ", $img_mtime->strftime("%F %T %z"), "\n";
            }
            $img_mtime->set_time_zone('local');

            # Set new timestamp.
            $exif_tool->SetNewValue(FileModifyDate => $img_mtime->date(':') . ' ' . $img_mtime->hms,
                                    Protected      => 1);

            # Write timestamp to file.
            my $success = $exif_tool->SetFileModifyDate($file);
#            print "FIXING date; success = $success\n";
        }

    }

    # Rename files.
    if ($opt_rename) {

        # Retrieve EXIF creation timestamp.
        my $parser = DateTime::Format::Strptime->new(
            pattern => '%Y:%m:%d %H:%M:%S');
        my $img_mtime = $parser->parse_datetime($$img_meta{'CreateDate'});

        # Retrieve file extension.
        my ($ext) = $file =~ /\.([^.]+)$/;

        # Constructing new name.
        my $new_file = $img_mtime->strftime($arg_rename_template) . '.' . $ext;

        # Create location if it doesn't exist yet.
        my ($nvol, $ndirs, $nfile) = File::Spec->splitpath($new_file);
        make_path $ndirs;

        # Finally, move the file.
        move($file, $new_file);
    }

#    {
#        foreach (keys %$img_meta) {
#            print "$_ => $$img_meta{$_}\n";
#        }
#    }

    print "\r[DONE]\n";
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

produce detailed output

--help

display this help

=cut
