#
# t/string-truncator.t
#
# Tests string utility truncating strings.
#

use strict;
use warnings;

use Test::More;
use Test::Exception;

use lib 'lib';

use TCO::String::Truncator;

# Constructor
throws_ok {
        TCO::String::Truncator->new(
            method => 'beginning',
            length => 10,
        )
    }
    qr/Error: constructor requires a hashref of attributes!/,
    'constructor: non-hashref parameter fails';

# Truncating

## Beginning
my $sentence = 'The quick brown fox jumps over the lazy dog.';
my $list     = 'pear--apple--cabbage--tomato--banana';
my $trunc = TCO::String::Truncator->new({
    method => 'beginning',
    length => '20',
});
is $trunc->truncate($sentence), '...ver the lazy dog.',
    'beginning: default delimiter and ellipsis';

$trunc = TCO::String::Truncator->new({
    method    => 'beginning',
    length    => '16',
    delimiter => ' ',
});
is $trunc->truncate($sentence), '...the lazy dog.',
    'beginning: default ellipsis and user specified delimiter';

$trunc = TCO::String::Truncator->new({
    method   => 'beginning',
    length   => '22',
    ellipsis => '..',
});
is $trunc->truncate($sentence), '..s over the lazy dog.',
    'beginning: default delimiter and user specified ellipsis';

$trunc = TCO::String::Truncator->new({
    method    => 'beginning',
    length    => '14',
    ellipsis  => '',
    delimiter => '--',
});
is $trunc->truncate($list), 'tomato--banana',
    'beginning: delimiter longer than ellipsis';

$trunc = TCO::String::Truncator->new({
    method    => 'beginning',
    length    => '16',
    ellipsis  => '',
    delimiter => '',
});
is $trunc->truncate($sentence), 'er the lazy dog.',
    'beginning: 0 char delimiter and ellipsis';


## End
my $trunc = TCO::String::Truncator->new({
    method => 'end',
    length => '20',
});
is $trunc->truncate($sentence), 'The quick brown f...',
    'end: default delimiter and ellipsis';

$trunc = TCO::String::Truncator->new({
    method    => 'end',
    length    => '16',
    delimiter => ' ',
});
is $trunc->truncate($sentence), 'The quick...',
    'end: default ellipsis and user specified delimiter';

$trunc = TCO::String::Truncator->new({
    method   => 'end',
    length   => '22',
    ellipsis => '..',
});
is $trunc->truncate($sentence), 'The quick brown fox ..',
    'end: default delimiter and user specified ellipsis';

$trunc = TCO::String::Truncator->new({
    method    => 'end',
    length    => '14',
    ellipsis  => '',
    delimiter => '--',
});
is $trunc->truncate($list), 'pear--apple',
    'end: delimiter longer than ellipsis';

$trunc = TCO::String::Truncator->new({
    method    => 'end',
    length    => '16',
    ellipsis  => '',
    delimiter => '',
});
is $trunc->truncate($sentence), 'The quick brown ',
    'end: 0 char delimiter and ellipsis';

done_testing;
