# Field printing an arbitrary string aligned on an arbitrary number of
# characters. Alignment and width are immutable and given at construction time.
# The payload data is specified upon prining.

package TCO::Output::Columnar::Field::Data;

use Moose;
use namespace::autoclean;
use MooseX::FollowPBP;
use MooseX::StrictConstructor;
use Carp 'croak';

extends 'TCO::Output::Columnar::Field';

our $VERSION = '0.1';
$VERSION = eval $VERSION;

use TCO::Output::Columnar::Types;
use TCO::String::Truncator;

# Number of characters the field can occupy.
has 'width' => (
    is       => 'ro',
    isa      => 'TCO::Output::Columnar::Types::FieldWidth',
    required => 1,
    reader   => '_get_width',
);

# Alignment of the printed data. Can be `left', `right' or `centre'.
has 'alignment' => (
    is       => 'ro',
    isa      => 'TCO::Output::Columnar::Types::FieldAlignment',
    required => 1,
    reader   => '_get_alignment',
);

# Truncator object used when the data is wider than the field.
has 'truncator' => (
    is      => 'ro',
    isa     => 'TCO::String::Truncator',
    reader  => '_get_truncator',
    lazy    => 1,
    builder => '_build_truncator',
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $type = 'data';

    if ( not (@_ == 1 && ref $_[0]) ) {
        croak "Error: constructor requires a hashref of attributes!";
    }

    my $arg_for = shift;
    $arg_for->{type} = $type;
    
    return $class->$orig( $arg_for );
};

# Builder method to initialise default truncator. Method depends on the
# alignment of the field.
sub _build_truncator {
    local $_;
    my $self = shift;

    my $align  = $self->_get_alignment;
    my $method;

    if ( $align == 'left' ) {
        $method = 'end';
    }
    elsif ( $align == 'middle' ) {
        # TODO: middle truncation
        #$method = 'middle';
        $method = 'end';
    }
    elsif ( $align == 'right' ) {
        $method = 'beginning';
    }
    return TCO::String::Truncator->new({
        method => $method,
        length => $self->_get_length,
    });
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
