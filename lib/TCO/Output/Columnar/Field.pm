# Base class for all fields. This is an abstract class and does nothing in
# itself. Use on of its subclasses.

package TCO::Output::Columnar::Field;

use Moose;
use MooseX::FollowPBP;
use namespace::autoclean;

our $VERSION = '0.1';
$VERSION = eval $VERSION;

__PACKAGE__->meta->make_immutable;

1;

