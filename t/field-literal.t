#
# t/field-literal.t
#
# Tests field of type `literal'.
#

use strict;
use warnings;

use Test::More;
use Test::Exception;

use lib 'lib';

use TCO::Output::Columnar::Field::Literal;

# Constructor
lives_ok {
        TCO::Output::Columnar::Field::Literal->new({
            string => 'this is a test',
        })
    }
    'constructor: successful instantiation';

throws_ok {
        TCO::Output::Columnar::Field::Literal->new(
            string => 'this is a test',
        )
    }
    qr/Error: constructor requires a hashref of attributes!/,
    'constructor: non-hashref parameter';

throws_ok {
        TCO::Output::Columnar::Field::Literal->new({
            string => {},
        })
    }
    qr/Attribute \(string\) does not pass the type constraint/,
    'constructor: non-string parameter';

# Rendering
my $field = TCO::Output::Columnar::Field::Literal->new({
    string => 'this is a test',
});
is $field->as_string, 'this is a test',
    'rendering field';

done_testing;
