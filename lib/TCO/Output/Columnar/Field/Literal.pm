# Field printing a constant string literal. The string literal is given at
# object creation.

package TCO::Output::Columnar::Field::Literal;

use Moose;
use MooseX::StrictConstructor;
use MooseX::FollowPBP;
use namespace::autoclean;
use Carp;

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

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my $args_ref;

    # Accept attributes in a hash or a hashref.
    if ( @_ == 1 && (ref $_[0] eq 'HASH') ) { $args_ref = shift; }
    else                                    { $args_ref = {@_};  }

    $args_ref->{type} = 'literal';
    return $class->$orig( $args_ref );
};

# Produces string representation of field.
sub as_string {
    my $self = shift;
    return sprintf $self->_get_string;
}

__PACKAGE__->meta->make_immutable;

1;
