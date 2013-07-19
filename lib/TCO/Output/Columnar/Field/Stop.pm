# Control field used to specify the end of a field group. When printing fields,
# all fields in a groups are processed in order until a `stop' field is
# encountered.

package TCO::Output::Columnar::Field::Stop;

use Moose;
use MooseX::FollowPBP;
use namespace::autoclean;

extends 'TCO::Output::Columnar::Field';

our $VERSION = '0.1';
$VERSION = eval $VERSION;

__PACKAGE__->meta->make_immutable;

1;

