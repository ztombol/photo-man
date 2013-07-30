# Class representing an digital image file.

package TCO::Image::File;

use Moose;
use MooseX::StrictConstructor;
use MooseX::FollowPBP;
use namespace::autoclean;
use Carp;

use Image::ExifTool;
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
    trigger  => \&_reload_metadata,
);

# EXIF metadata associated with the image.
has 'metadata' => (
    is       => 'rw',
    isa      => 'Ref',
    reader   => 'get_metadata',
    writer   => '_set_metadata',
    lazy     => 1,
    builder  => '_load_metadata',
);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;

    if ( not (@_ == 1 && ref $_[0]) ) {
        croak "Error: constructor requires a hashref of attributes!";
    }

    return $class->$orig( @_ );
};

# Builder method to load metadata.
sub _load_metadata {
    local $_;
    my $self = shift;

    # Extract metadata.
    my $exif_tool = new Image::ExifTool;
    my $exif_meta = $exif_tool->ImageInfo( $self->get_path );

    return $exif_meta;
}

# Trigger method to reload metadata. Used when path is changed.
sub _reload_metadata {
    my ( $self, $new_path, $old_path ) = @_;
    $self->_set_metadata( $self->_load_metadata($new_path) );
}

# Moves the file to a new location. Also creates the directories leading up to
# the destination if they do not exist yet. The operation is executed only if
# the the image is not in `read only' mode, in which case success is returned
# immediately. This behaviour is implemented to support dry-run mode.
#
# @param [in] self    file to move (source)
# @param [in] target  new path including filename (destination)
#
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
