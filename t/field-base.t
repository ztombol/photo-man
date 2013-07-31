#
# t/field-base.t
#
# Tests field that is the parent class of the other fields.
#

use strict;
use warnings;

use Test::More;
use Test::Exception;

use lib 'lib';

use TCO::Output::Columnar::Field::Data;

# Constructor
lives_ok {
        TCO::Output::Columnar::Field->new({
            type => 'test',
        })
    }
    'constructor: successful instantiation';

throws_ok {
        TCO::Output::Columnar::Field->new({
            type => {},
        })
    }
    qr/Attribute \(type\) does not pass the type constraint/,
    'constructor: non-string parameter';

done_testing;
