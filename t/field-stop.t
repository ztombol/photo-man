#
# t/field-stop.t
#
# Tests field of type `stop'.
#

use strict;
use warnings;

use Test::More;
use Test::Exception;

use lib 'lib';

use TCO::Output::Columnar::Field::Stop;

# Constructor
lives_ok {
        TCO::Output::Columnar::Field::Stop->new()
    }
    'constructor: successful instantiation';

throws_ok {
        TCO::Output::Columnar::Field::Stop->new({
            param => 'unnecessary',
        })
    }
    qr/Error: constructor requires no parameters!/,
    'constructor: unnecessary paramter';

done_testing;
