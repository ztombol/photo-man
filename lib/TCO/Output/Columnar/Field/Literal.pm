# Field printing a constant string literal. The string literal is given at
# object creation.

package TCO::Output::Columnar::Field::Literal;

use Moose;
use MooseX::FollowPBP;
use namespace::autoclean;

extends 'TCO::Output::Columnar::Field';

our $VERSION = '0.1';
$VERSION = eval $VERSION;

# String to output.
has 'string' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    reader   => '_get_string',
);

# Allow non-hash(ref) calling style.
around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $type = 'literal';

    if ( @_ == 1 && ref $_[0] ) {
        my $arg_for = shift;
        return $class->$orig(
            type   => $type,
            string => $arg_for->{string},
        );
    }
};

# Produces string representation of field.
sub as_string {
    my $self = shift;
    return sprintf $self->_get_string;
}

__PACKAGE__->meta->make_immutable;

1;

