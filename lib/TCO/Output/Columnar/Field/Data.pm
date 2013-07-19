# Field printing an arbitrary string aligned on an arbitrary number of
# characters. Alignment and width are immutable and given at construction time.
# The payload data is specified upon prining.

package TCO::Output::Columnar::Field::Data;

use Moose;
use MooseX::FollowPBP;
use namespace::autoclean;
#use overload '""' => 'as_string';
use Carp 'croak';

extends 'TCO::Output::Columnar::Field';

our $VERSION = '0.1';
$VERSION = eval $VERSION;

# Number of characters the field can occupy.
has 'width' => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
    reader   => '_get_width',
);

# Alignment of the printed data. Can be `left', `right' or `centre'.
has 'alignment' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    reader   => '_get_alignment',
);

# Allow non-hash(ref) calling style.
around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    if ( @_ == 2 && !ref $_[0] ) {
        return $class->$orig( alignment => $_[0],
                              width     => $_[1] );
    }
    else {
        return $class->$orig( @_ );
    }
};

# Validate created object.
sub BUILD {
    my $self = shift;

    # Width.
    if ( not $self->_get_width > 0 ) {
        croak("Width must be an integer greater than 0");
    }

    # Alignment.
    if ( not grep { $self->_get_alignment eq $_ } qw(left centre right) ) {
        croak("Alignment must be one of `left', `centre' or `right'");
    }
}

# Produces string representation of field.
sub as_string {
    my $self = shift;
    my $data = shift;

    if ( $self->_get_alignment eq 'centre' ) {
        # Centre alignment. Pad text with spaces on both sides.
        my $data_width = length $data;
        my $left_pad = int( ($self->_get_width - $data_width) / 2 );
        my $right_pad = $self->_get_width - ($data_width + $left_pad);
        return sprintf( "%${left_pad}s%s%${right_pad}s", '', $data, '' );
    }
    else {
        # Left/Right alignment.
        my $alignment = ($self->_get_alignment eq 'left') ? '-' : '';
        return sprintf( "%${alignment}" . $self->_get_width . "s", $data );
    }
}

__PACKAGE__->meta->make_immutable;

1;

