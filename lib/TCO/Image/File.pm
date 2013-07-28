# Class representing an digital image file.

package TCO::Image::File;

use Moose;
use MooseX::FollowPBP;
use namespace::autoclean;

use Image::ExifTool;
use File::Copy;
use File::Path qw(make_path);
#use Carp;

our $VERSION = '0.1';
$VERSION = eval $VERSION;

# Filename of image.
has 'path' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    reader   => 'get_path',
    writer   => '_set_path',
    trigger  => \&_reload_metadata,
);

# EXIF metadata associated with the image.
has 'metadata' => (
    is       => 'rw',
    isa      => 'Ref',
    required => 1,
    reader   => 'get_metadata',
    writer   => '_set_metadata',
);


around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;

    my $path;
    my $read_only;

    if ( @_ == 1 && ref $_[0] ) {
        # Hashref.
        my $arg_for = shift;

        $path = $arg_for->{path};
    }
    else {
        # Parameter list.
        $path = shift;
    }

    # Retrieve metadata.
    my $metadata = $class->_initialise( $path );

    return $class->$orig(
        path         => $path,
        metadata     => $metadata,
    );
};

sub _initialise {
    my $class = shift;
    my $path = shift;

    # Extract metadata.
    my $exif_tool = new Image::ExifTool;
    my $exif_meta = $exif_tool->ImageInfo( $path );

    return $exif_meta;
}

sub _reload_metadata {
    my $self = shift;
    my $path = shift;

    $self->_set_metadata( $self->_initialise($path) );
}


# Moves the file to a new location. Also creates the directories leading up to
# the destination if they do not exist yet. The operation is executed only if
# the the image is not in `read only' mode, in which case success is returned
# immediately. This behaviour is implemented to support dry-run mode.
#
# @param [in] $self    file to move (source)
# @param [in] $target  new path including filename (destination)
# @returns  0 on success,
#           1 otherwise
sub move_file {
    my $self = shift;
    my $target = shift;

    # Make sure the directory tree exists up to the Target.
    my $dirs = ( File::Spec->splitpath( $target ) )[2];
    make_path( $dirs );

    my $result;
    if ( $result = move($self->get_path, $target ) ) {
        # File moved successfully. Update path and metadata.
        $self->set_path( $target );
    }
    # Flip result. move returns 1 on success and 0 on error.
    return not $result;
}

__PACKAGE__->meta->make_immutable;

1;
