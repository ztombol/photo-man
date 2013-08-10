# Class representing an digital image file.

package TCO::Image::File;

use Moose;
use MooseX::StrictConstructor;
use MooseX::FollowPBP;
use namespace::autoclean;
use Carp;

use Image::ExifTool;
use File::stat;
use File::Copy;
use File::Path qw(make_path);

our $VERSION = '0.1';
$VERSION = eval $VERSION;

# Filename of image.
has 'path' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    reader   => 'get_path',
    writer   => '_set_path',
    trigger  => \&_reload_meta,
);

# EXIF metadata associated with the image.
has 'img_meta' => (
    is       => 'rw',
    isa      => 'Ref',
    reader   => 'get_img_meta',
    writer   => '_set_img_meta',
    lazy     => 1,
    builder  => '_load_img_meta',
);

# File system metadata.
has 'fs_meta' => (
    is      => 'rw',
    isa     => 'Ref',
    reader  => 'get_fs_meta',
    writer  => '_set_fs_meta',
    lazy    => 1,
    builder => '_load_fs_meta',
);

# Exiftool object for metadata operations, e.g. reading/writing tags.
has 'exiftool' => (
    is      => 'ro',
    isa     => 'Ref',
    reader  => '_get_exiftool',
    default => sub { new Image::ExifTool },
);

# Loads file system metadata, e.g. timestamps, ownership, permissions, etc.
#
# @returns a File::stat object containing the file system metadata
sub _load_fs_meta {
    local $_;
    my $self = shift;

    return stat( $self->get_path );
}

# Loads metadata found in the image file, e.g. EXIF, IPTC, XMP, etc.
#
# @returns a hashref containing metadata embedded in the image file
sub _load_img_meta {
    local $_;
    my $self = shift;

    # Extract metadata.
    my $exif_tool = new Image::ExifTool;
    return $exif_tool->ImageInfo( $self->get_path );
}

# Reloads file system and image embedded metadata. Triggered when path is
# changed.
sub _reload_meta {
    my ( $self, $new_path, $old_path ) = @_;
    $self->_set_fs_meta( $self->_load_fs_meta );
    $self->_set_img_meta( $self->_load_img_meta );
}

# Moves the file and creates the directories leading up to the new location if
# they do not exist already.
#
# @param [in] $1  new path of file (includes filename)
# return  0 on success
#         1 otherwise
sub move_file {
    my $self = shift;
    my $dest = shift;

    # Make sure the directory tree exists up to the destination.
    make_path( (File::Spec->splitpath($dest))[1] );

    my $result;
    if ( $result = move($self->get_path, $dest) ) {
        # File moved successfully. Update path and metadata.
        $self->_set_path( $dest );
    }

    # Flip result. move returns 1 on success and 0 on error.
    return not $result;
}

# Same as above just using exiftool to move the file and create necessary
# directories.
#sub move_file {
#    my $self = shift;
#    my $dest = shift;
#
#    my $exif_tool = new Image::ExifTool;
#
#    # This performs the move immediately
#    my $result = $exif_tool->SetFileName(
#        $self->get_path,
#        $dest,
#    );
#
#    return not $result;
#}

# Changes the file system modification timestamps of the file.
#
# @param [in] $
# return  0 on success
#         1 otherwise
sub set_mod_time {
    my $self = shift;
    my $mtime = shift;
    my $exiftool = $self->_get_exiftool;

    # Setting new timestamp.
    my ( $success, $err_str ) = $exiftool->SetNewValue(
        FileModifyDate => $mtime,
        Protected      => 1,
    );

    if ( $success && $exiftool->SetFileModifyDate($self->get_path) != -1 ) {
        # Reload metadata and return success.
        $self->_reload_meta;
        return 0;
    }

    # Failure.
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
