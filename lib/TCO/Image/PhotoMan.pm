# Class exposing photo management related functions.

package TCO::Image::PhotoMan;

use Moose;
use MooseX::FollowPBP;
use namespace::autoclean;

use TCO::Image::File;

use File::Compare;
use File::stat;

our $VERSION = '0.1';
$VERSION = eval $VERSION;

# Make changes to files (1) or not (0).
has 'do_commit' => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    reader   => 'do_commit',
);

# Execute destructive operations such as overwriting (1) or not (0).
has 'is_forced' => (
    is => 'ro',
    isa => 'Bool',
    required => 1,
    reader => 'is_forced',
);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;

    if ( @_ == 2 ) {
        # Parameter list.
        my $do_commit = shift;
        my $is_forced = shift;
        return $class->$orig(
            do_commit => $do_commit,
            is_forced => $is_forced,
        );
    }
    else {
        # Hashref.
        return $class->$orig( @_ );
    }
};

# Moves the image to a new location and/or renames it. The new location and
# filename is specified with templates that lets the user to combine string
# literals and parts of the creation timestamp from the metadata of the image.
#
# NOTE: As a side-effect, this function also updates the `path' in the image
# object.
#
# @param [in] image  to move and/or rename
# @param [in] location_temp  template used to produce the new location for moving
# @param [in] filename_temp  template used to produce the new filename for
# renaming
#
# returns  -1 in case of errors
#           0 successful moving/renaming
#           1 file at the destination overwritten
#           2 another file already exists with the same path
#           3 the file is already at the path
sub move_and_rename {
    my $self = shift;

    my $image;
    my $location_temp;
    my $filename_temp;

    my $status;

    if ( @_ == 1 ) {
        # Hashref.
        my $arg_for = shift;
        $image         = $arg_for->{image};
        $location_temp = $arg_for->{location_temp};
        $filename_temp = $arg_for->{filename_temp};
    }
    else {
        # List.
        $image         = shift;
        $location_temp = shift;
        $filename_temp = shift;
    }

    # Assemble new path.
    my $new_file = $self->_make_path( $image, $location_temp, $filename_temp);

    # Attempt to move the file.
    if ( ! -e $new_file ) {
        # Target file does not exists. Move the file!
        if ( $self->do_commit ) {
            $image->move_file( $new_file );
        }
        $status = 0;
    }
    elsif ( $image->get_path eq $new_file ) {
        # Source and Target are the same. Nothing to do!
        $status = 3;
    }
    else {
        # There exists a file at the Target already.
        my $cmp = compare( $image->get_path, $new_file );
        if ( $cmp == 1 ) {
            # Target is different from Source. Can we overwrite?
            if ( $self->do_commit && $self->is_forced ) {
                $image->move_file( $new_file );
            }
            $status = 1;
        }
        elsif ( $cmp == 0 ) {
            # Source and Target are the same file. Nothing to do!
            $status = 2;
        }
    }

    # Return status code and new path.
    return ( $status, $new_file );
}

# Creates a path based on location (for directory) and filename templates (for
# the actual filename portion). The path is created by interpolating the
# remplates with parts of the creation timestamp stored as image metadata.
# The templates are optional. If a template is not supplied, the original value
# will be used. For example, if location template is specified but filename
# template is not, then the new path will consist of the new location and the
# original filename.
#
# @param [in] $1  image to create path for
# @param [in] $2  location template (optional)
# @param [in] $3  filename template (optional)
sub _make_path {
    my $self = shift;

    my $image         = shift;
    my $location_temp = shift;
    my $filename_temp = shift;
    
    my $new_location = ( defined $location_temp ) ?
        $self->_template_to_str( $image, $location_temp ) :
        ( File::Spec->splitpath($image->get_path) )[1];

    my $new_filename = ( defined $filename_temp ) ?
        $self->_template_to_str( $image, $filename_temp ) :
        ( File::Spec->splitpath($image->get_path) )[2];

    return File::Spec->catfile( $new_location, $new_filename );
}

# Constructs string using string literals and parts of the creation timestamp
# from metadata stored in the image.
#
# @param [in] $image     to extract metadata from
# @param [in] $template  string to interpolate
sub _template_to_str {
    my $self = shift;

    my $image    = shift;
    my $template = shift;


    # Parser the date from metadata.
    my $img_ctime_parser = DateTime::Format::Strptime->new(
        pattern   => '%Y:%m:%d %H:%M:%S',
    );
    my $img_ctime = $img_ctime_parser->parse_datetime(
        $image->get_metadata->{'CreateDate'}
    );

    # Return interpolated string.
    return $img_ctime->strftime( $template );
}

# Sets the file system modification timestamp to the EXIF creation timestamp.
#
# @param [in] $image     whose timestamp will be modified
# @param [in] $timezone  where the photo was taken
#
# returns  -1 in case of errors
#           0 timestamp successfully changed
#           1 timestamp already correct
sub fix_timestamp {
    my $self = shift;

    my $image;
    my $timezone;

    my $status;

    if ( @_ == 1 ) {
        # Hashref.
        my $arg_for = shift;
        $image    = $arg_for->{image};
        $timezone = $arg_for->{timezone};
    }
    else {
        # List.
        $image    = shift;
        $timezone = shift;
    }

    my $local_tz = DateTime::TimeZone->new( name => 'local' );

    # File system timestamp.
    my $fs_meta = stat( $image->get_path );
    my $fs_mtime = DateTime->from_epoch(
        epoch     => $fs_meta->mtime,
        time_zone => $local_tz,
    );
    
    # EXIF creation timestamp.
    my $img_mtime_parser = DateTime::Format::Strptime->new(
        pattern   => '%Y:%m:%d %H:%M:%S',
        time_zone => $timezone,
    );
    my $img_mtime = $img_mtime_parser->parse_datetime(
        $image->get_metadata->{'CreateDate'}
    );
    $img_mtime->set_formatter($img_mtime_parser);

    # Convert timestamp to local time zone. So the correct date and
    # time is stringified when we set the file system timestamp.
    # TODO: should I move it back to the if-true branch?
    $img_mtime->set_time_zone( $local_tz );

    # Set new timestamp if needed.
    if (   $img_mtime->truncate(to => 'second')
        != $fs_mtime->truncate( to => 'second') ) {
        # Timestamp is not correct.

        # Write timestamp to file if we are not making a dry-run.
        if ( $self->do_commit ) {
            my $exif_tool = new Image::ExifTool;
            $exif_tool->SetNewValue( FileModifyDate => $img_mtime,
                                     Protected      => 1,
            );

            if ( not $exif_tool->SetFileModifyDate($image->get_path) ) {
                # Something went wrong.
                $status = -1;
            }
        }
        $status = 0;
    }
    else {
        $status = 1;
    }

    # Return status and new timestamp.
    return ( $status, $img_mtime );
}

__PACKAGE__->meta->make_immutable;

1;
