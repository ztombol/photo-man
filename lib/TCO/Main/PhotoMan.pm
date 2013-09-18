#!/usr/bin/env perl

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

package TCO::Main::PhotoMan;

__PACKAGE__->run( @ARGV ) unless caller();

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

our $VERSION = '0.1';
$VERSION = eval $VERSION;


###############################################################################
# Global variables
###############################################################################

our ($record, $header); # Output formatters.
our $is_verbose;        # Output verbosity.


###############################################################################
# Main
###############################################################################

# Main function, runs when called from command line.
sub run {
    my $class = shift;
    my @argv = @_;

    # Parse options, and check if the configuration they define is valid.
    my %args = $class->parse_options( \@argv );
    $class->print_config( %args );
    $class->check_config( %args );

    # Initialise output formatters.
    ( $header, $record ) = $class->init_output( %args );

    # Create photo manager instance.
    my $manager = TCO::Image::PhotoMan->new(
        commit => $args{ commit },
        forced => $args{ forced },
    );

    # Processing each file.
    print ":: Processing images\n";

    # Print column header.
    if ( $is_verbose ) { }
    else               { $header->print(); }

    # Assemble pattern that will be used for globbing.
    my $pattern = '{' . join(',', @argv) . '}';
    while (my $file = glob("$pattern")) {
    
        # Load file.
        my $image = TCO::Image::File->new( path => $file );
        
        # Perform requested actions on file.
        $class->process_image(
            image   => $image,
            manager => $manager,
            args    => \%args,
        );
    }

    # Print summary
    $class->print_summary( $manager);
}

###############################################################################
# Parse options and check arguments
###############################################################################

# Parse options.
{
    # The handler will store options and their arguments in this hash.
    my %args;

    sub parse_options {
        my $class = shift;
        my $argv_ref = shift;

        # Needs to be initialised with an empty hash so the parse subroutine
        # can be called repeatedly in tests.
        %args = ();

        my $parser = Getopt::Long::Parser->new;
        $parser->getoptionsfromarray( $argv_ref,
            'touch=s'   => \&handler,   # Fix timestamp + original time zone
            'move=s'    => \&handler,   # Move files    + template of new location
            'rename:s'  => \&handler,   # Rename files  + template of new filename
            'use-magic' => \&handler,   # Use magic number to get extension
            'commit'    => \&handler,   # Make changes, not just a dry run
            'force'     => \&handler,   # Perform destructive operations, e.g. overwrite
            'verbose'   => \$is_verbose,# Print verbose output
            'help'      => \&handler,   # Display help
            'man'       => \&handler,   # Show the complete documentation
        ) or pod2usage( -input => 'photo-man.pod', -verbose => 0, -exitval => 2 );

        # Displaying help or complete documentation.
        pod2usage( -input => 'photo-man.pod', -verbose => 1) if $args{ help };
        pod2usage( -input => 'photo-man.pod', -verbose => 2, -exitval => 0) if $args{ man };
    
        # Check input files.
        pod2usage( -input => 'photo-man.pod', -verbose => 1,
                   -message => "$0: No input files specified.") if (@{$argv_ref} == 0 && -t STDIN);

        return %args;
    }

    # Handler for Getopt options.
    sub handler {
        my ($opt_name, $opt_arg) = @_;
        $args{$opt_name} = $opt_arg;
    }
}

# Validates the combination of the options and arguments passed to the script.
#
# @param [in] %args  options and their arguments
sub check_config {
    my $class = shift;
    my %args = @_;

    # The argument to --rename is optional only if --use-magic is also used.
    if ( defined $args{ rename } && $args{ rename } eq '' && ! $args{'use-magic'} ) {
        die 'The --rename option requires a non-empty string argument';
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
    my $class = shift;
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


###############################################################################
# Auxiliary functions
###############################################################################

sub process_image {
    my $class = shift;
    my $args_ref;

    if ( @_ == 1 && (ref $_[0] eq 'HASH') ) { $args_ref = shift; }
    else                                    { $args_ref = {@_};  }

    my $image   = $args_ref->{ image };
    my $args    = $args_ref->{ args };
    my $manager = $args_ref->{ manager };

    # Print file name.
    if ( $is_verbose ) { $header->print( $image->get_path ); }
    else               { $record->print( $image->get_path ); }

    # Acions.
    $class->op_move_and_rename(
            manager => $manager,
            image   => $image,
            move    => $args->{ move },
            rename  => $args->{ rename },
            magic   => $args->{'use-magic'},
        )
        if ( defined $args->{ move } || defined $args->{ rename } );

    $class->op_fix_timestamp(
            manager  => $manager,
            image    => $image,
            timezone => $args->{ touch }
        )
        if ( defined $args->{ touch } );

    # Print overall result of all operations.
    if ( $is_verbose ) { print "\n"; }
    # FIXME: this prints done even if one of the operations fail!
    else               { $record->print('done'); }
}

# Moves and/or renames a file and prints appropriate output.
#
# @param [in]     $manager        that executes the action
# @param [in,out] $image          to move and rename
# @param [in]     $location_temp  template of new location
# @param [in]     $filename_temp  template of new filename
#
# NOTE: this subroutine accesses variables from global scope!
#       $record, $header, $is_verbose
sub op_move_and_rename {
    my $class = shift;
    my $args_ref;

    if ( @_ == 1 && (ref $_[0] eq 'HASH') ) { $args_ref = shift; }
    else                                    { $args_ref = {@_};  }

    my $manager       = $args_ref->{ manager };
    my $image         = $args_ref->{ image };
    my $location_temp = $args_ref->{ move };
    my $filename_temp = $args_ref->{ rename };
    my $use_libmagic  = $args_ref->{ magic };

    # Perform action.
    # FIXME: this is a work around of getting results in dry-run, will be
    #        removed after Image::File implements journaling support
    my ($status, $new_path) = $manager->move_and_rename(
    #my $status = $manager->move_and_rename(
        image         => $image,
        location_temp => $location_temp,
        filename_temp => $filename_temp,
        use_libmagic  => $use_libmagic,
    );
    #my $new_path = $image->get_path;

    # Print output.
    $class->out_move_and_rename( $status, $new_path );
}

# Produces output for move and rename operations.
sub out_move_and_rename {
    my ($class, $status, $new_path) = @_;

    if ( $is_verbose ) {
        $record->print( 'move' );

          $status == 0 ? $record->print('moved', $new_path)
        : $status == 1 ? $record->print('overwritten', $new_path)
        : $status == 2 ? $record->print('same file at', $new_path)
        : $status == 3 ? sub { $record->print("already at");
                               $record->reset(); }->()
        : $status ==-1 ? croak "MOVE: error while moving file"
        : $status ==-2 ? $record->print('error!', 'missing timestamp')
        :                croak "MOVE: unhandled return value $status";
    }
    else {
          $status == 0 ? $record->print('move')
        : $status == 1 ? $record->print('over')
        : $status == 2 ? $record->print('same')
        : $status == 3 ? $record->print('there')
        : $status ==-1 ? croak "MOVE: error while moving file"
        : $status ==-2 ? $record->print('error!', 'missing timestamp')
        :                croak "MOVE: unhandled return value $status";

	if ( $status >= 0 ) {
            $record->print( $new_path );
    	}
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
#       $record, $header, $is_verbose
sub op_fix_timestamp {
    my $class = shift;
    my $args_ref;

    if ( @_ == 1 && (ref $_[0] eq 'HASH') ) { $args_ref = shift; }
    else                                    { $args_ref = {@_};  }

    my $manager  = $args_ref->{ manager };
    my $image    = $args_ref->{ image };
    my $timezone = $args_ref->{ timezone };

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
    $class->out_fix_timestamp( $status, $new_time );
}

# Produces output for timestamp change operations.
sub out_fix_timestamp {
    my ($class, $status, $new_time) = @_;

    if ( defined $new_time ) {
        my $parser = DateTime::Format::Strptime->new(
            pattern   => '%Y:%m:%d %H:%M:%S',
        );
        $new_time->set_formatter($parser);
    }

    if ( $is_verbose ) {
        $record->print( 'time' );

          $status == 0 ? $record->print('changed', $new_time)
        : $status == 1 ? sub { $record->print("correct");
                               $record->reset(); }->()
        : $status ==-1 ? croak "TOUCH: error while modifying timestamp"
        : $status ==-2 ? $record->print('error!', 'missing timestamp')
        :                croak "TOUCH: unhandled return value $status";
    }
    else {
          $status == 0 ? $record->print( $new_time )
        : $status == 1 ? $record->print('--')
        : $status ==-1 ? croak 'TOUCH: error while modifying timestamp'
        : $status ==-2 ? $record->print('!!! missing !!!')
        :                croak 'TOUCH: unhandled return value $status';
    }
}

sub print_summary {
    my $class = shift;
    my $manager = shift;

    print ":: Summary\n";

    # TODO: print summary, number of moved files etc.

    # Warn if it was just a dry run
    if ( not $manager->do_commit ) {
        print <<"WARNING";

!!! HEADS-UP !!!

This was just a dry-run! If you want to make the changes above add `--commit'
to your command!

    \$ $0 --commit ...

WARNING
    }
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
    my $class = shift;
    my %args = @_;

    my ($out_header, $out_record);

    if ( $is_verbose ) {
        # Verbose (vertical) output. Print messages on their own separate line.
        $out_header = TCO::Output::Columnar::Format->new( format  => "@<\n" );
        $out_record = TCO::Output::Columnar::Format->new(
            format  => "[@|||||] @>>>>>>>>>>>> > @...<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n",
            control => "        ^             ^                                        ",
        );
    }
    else {
        # Normal (horizontal) output. Print messages on adjecent cells on the
        # same line.

        # Base: result and filename.
        $out_header = TCO::Output::Columnar::Format->new(
            # This is SHORTER by ONE character so we can have a different
            # trailing character depending if move/rename is specified or not.
            #
            #          v---------- complete length ----------v
            format  => "[result] [ file                     "
                    . ( (defined $args{move} || defined $args{rename})
                    ? " " : "]" ),
        );
        $out_record = TCO::Output::Columnar::Format->new(
            format  => "[      ] @...<<<<<<<<<<<<<<<<<<<<<<<<",
        );
     
        # Move and rename.
        if ( defined $args{ move } || defined $args{ rename } ) {
            $out_header->append( format => " > action > new path                   ]" );
            $out_record->append( format => " >@|||||||> @...<<<<<<<<<<<<<<<<<<<<<<<<" );
        }

        # Timestamp fix.
        if ( defined $args{ touch } ) {
            $out_header->append( format  => " [    timestamp    ]" );
            $out_record->append( format  => " @||||||||||||||||||" );
        }

        # End of record: add line feed or overall result.
        $out_header->append( format => "\n" );
        $out_record->append( format => "\r[@|||||]\n" );
    }

    # Return output objects.
    return ( $out_header, $out_record );
}

1;
