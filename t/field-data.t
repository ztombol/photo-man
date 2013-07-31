#
# t/field-data.t
#
# Tests field of type `data'.
#

use strict;
use warnings;

use Test::More;
use Test::Exception;

use lib 'lib';

use TCO::Output::Columnar::Field::Data;

# Constructor
lives_ok {
        TCO::Output::Columnar::Field::Data->new({
            alignment => 'left',
            width     => 10,
        })
    }
    'constructor: successful instantiation';

throws_ok {
        TCO::Output::Columnar::Field::Data->new(
            alignment => 'left',
            width     => 10,
        )
    }
    qr/Error: constructor requires a hashref of attributes!/,
    'constructor: non-hashref parameter';

throws_ok {
        TCO::Output::Columnar::Field::Data->new({
            alignment => 'left',
            width     => -2,
        })
    }
    qr/Field width must be a positive integer/,
    'constructor: error on incorrect width';

throws_ok {
        TCO::Output::Columnar::Field::Data->new({
            alignment => 'bad_alignement',
            width     => 10,
        })
    }
    qr/Field alignment must be one of `left', `centre' or `right'/,
    'constructor: error on incorrect alignment';

# Alignment
my $field = TCO::Output::Columnar::Field::Data->new({
    alignment => 'left',
    width     => 10,
});
is $field->as_string('test'), 'test      ',
    'left aligned data field';

$field = TCO::Output::Columnar::Field::Data->new({
    alignment => 'centre',
    width     => 10,
});
is $field->as_string('test'), '   test   ',
    'centre aligned data field';

$field = TCO::Output::Columnar::Field::Data->new({
    alignment => 'right',
    width     => 10,
});
is $field->as_string('test'), '      test',
    'right aligned data field';

# Data too wide
TODO: {
    local $TODO = 'Trimming data too wide to fit is not yet implemented';
    
    # Default
    $field = TCO::Output::Columnar::Field::Data->new({
        alignment => 'left',
        width     => 10,
    });
    is $field->as_string('this is a test'), 'this is...',
        'default trimming on left aligned field';

    $field = TCO::Output::Columnar::Field::Data->new({
        alignment => 'centre',
        width     => 10,
    });
    is $field->as_string('this is a test'), 'this is...',
        'default trimming on centre aligned field';

    $field = TCO::Output::Columnar::Field::Data->new({
        alignment => 'right',
        width     => 10,
    });
    is $field->as_string('this is a test'), '... a test',
        'default trimming on right aligned field';

    # Beginning
    $field = TCO::Output::Columnar::Field::Data->new({
        alignment => 'left',
        width     => 10,
#        trimming  => 'beginning',
    });
    is $field->as_string('this is a test'), '... a test',
        'trimming at the `beginning\' on left aligned field';

    $field = TCO::Output::Columnar::Field::Data->new({
        alignment => 'centre',
        width     => 10,
#        trimming  => 'beginning',
    });
    is $field->as_string('this is a test'), '... a test',
        'trimming at the `beginning\' on centre aligned field';

    $field = TCO::Output::Columnar::Field::Data->new({
        alignment => 'right',
        width     => 10,
#        trimming  => 'beginning',
    });
    is $field->as_string('this is a test'), '... a test',
        'trimming at the `beginning\' on left aligned field';
    
    # End
    $field = TCO::Output::Columnar::Field::Data->new({
        alignment => 'left',
        width     => 10,
#        trimming  => 'end',
    });
    is $field->as_string('this is a test'), 'this is...',
        'trimming at the `end\' on left aligned field';

    $field = TCO::Output::Columnar::Field::Data->new({
        alignment => 'centre',
        width     => 10,
#        trimming  => 'end',
    });
    is $field->as_string('this is a test'), 'this is...',
        'trimming at the `end\' on centre aligned field';

    $field = TCO::Output::Columnar::Field::Data->new({
        alignment => 'right',
        width     => 10,
#        trimming  => 'end',
    });
    is $field->as_string('this is a test'), 'this is...',
        'trimming at the `end\' on left aligned field';
}

done_testing;
