# Base class for all fields. This is an abstract class and does nothing in
# itself. Use on of its subclasses.

package TCO::Output::Columnar::Field;

use Moose;
use MooseX::FollowPBP;
use namespace::autoclean;

our $VERSION = '0.1';
$VERSION = eval $VERSION;

has 'type' => (
    is     => 'ro',
    isa    => 'Str',
    reader => 'get_type',
);

__PACKAGE__->meta->make_immutable;

1;

