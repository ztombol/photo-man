# Control field used to specify the end of a field group. When printing fields,
# all fields in a groups are processed in order until a `stop' field is
# encountered.

package TCO::Output::Columnar::Field::Stop;

use Moose;
use MooseX::StrictConstructor;
use MooseX::FollowPBP;
use namespace::autoclean;
use Carp;

extends 'TCO::Output::Columnar::Field';

our $VERSION = '0.1';
$VERSION = eval $VERSION;

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $type = 'stop';

    return $class->$orig(
        type => $type,
    );
};

__PACKAGE__->meta->make_immutable;

1;

