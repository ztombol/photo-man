package TestsFor::TCO::Output::Columnar::Format;

use Test::Most;
use Capture::Tiny qw(capture_merged capture capture_stdout);
use base 'TestsFor';
use TCO::Output::Columnar::Format;

sub class_to_test { 'TCO::Output::Columnar::Format' }

sub constructor : Tests {
    my $self  = shift;
    my $class = $self->class_to_test;

    can_ok $class, 'new';
    throws_ok { $class->new }
        qr/Attribute.*required/,
        "Creating a $class without proper attributes should fail";
    isa_ok $self->default_formatter, $class;
}

sub print : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my $fmt;

    # Format only.
    $fmt = $class->new(
        format  => "[      ] @>>>>>>> => @<<<<<<<   @>>>>>> = @<<<<<< (@>>>>s)\r[@|||||]\n",
    );
    eq_or_diff [
            scalar capture_merged { $fmt->print('reading', 'database') },
            scalar capture_merged { $fmt->print('port', 54190)         },
            scalar capture_merged { $fmt->print('9.43')                },
            scalar capture_merged { $fmt->print('DONE')                },
        ],[
            "[      ]  reading => database   ",
            "   port = 54190   (",
            " 9.43s)\r[",
            " DONE ]\n",
        ],
        'format string defined output should render correctly';

    # Format + Control.
    $fmt = $class->new(
        format  => "[      ] @>>>>>>> => @<<<<<<<   @>>>>>> = @<<<<<< (@>>>>s)\r[@|||||]\n",
        control => "                             ^                   ^        ^         ",
    );
    eq_or_diff [
            scalar capture_merged { $fmt->print('reading', 'database')  },
            scalar capture_merged { $fmt->print('port', 54190)          },
            scalar capture_merged { $fmt->print('9.43')                 },
            scalar capture_merged { $fmt->print('DONE')                 },
        ],[
            "[      ]  reading => database",
            "      port = 54190  ",
            " ( 9.43s)",
            "\r[ DONE ]\n",
        ],
        'format and control string defined output should render correctly';

    # Multi-line.
    $fmt = $class->new(
        format  => "[      ] @>>>>>>> => @<<<<<<<   @>>>>>> = @<<<<<< (@>>>>s)\r[@|||||]\n",
        control => "                             ^                   ^        ^         ",
    );
    eq_or_diff [
            scalar capture_merged { $fmt->print('reading', 'database')  },
            scalar capture_merged { $fmt->print('port', 54190)          },
            scalar capture_merged { $fmt->print('9.43')                 },
            scalar capture_merged { $fmt->print('DONE', 'reading', 'database')  },
            scalar capture_merged { $fmt->print('port', 54190)          },
        ],[
            "[      ]  reading => database",
            "      port = 54190  ",
            " ( 9.43s)",
            "\r[ DONE ]\n[      ]  reading => database",
            "      port = 54190  ",
        ],
        'excessive number of data should cause multiple lines to render';
}

sub append : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my $fmt;
    
    # With and without stop.
    $fmt = $class->new(
        format  => "[      ] @>>>>>>> => @<<<<<<<",
        control => "                             ",
    );
    $fmt->append(
        format  => "   @>>>>>> = @<<<<<<",
        control => "^                   ",
    );
    $fmt->append(
        format  => " (@>>>>s)",
        control => "         ",
    );
    $fmt->append(
        format  => "\r[@|||||]\n",
        control => "^         ",
    );
    eq_or_diff [
            scalar capture_merged { $fmt->print('reading', 'database')  },
            scalar capture_merged { $fmt->print('port', 54190)          },
            scalar capture_merged { $fmt->print('9.43')                 },
            scalar capture_merged { $fmt->print('DONE')                 },
        ],[
            "[      ]  reading => database",
            "      port = 54190   (",
            " 9.43s)",
            "\r[ DONE ]\n",
        ],
        'appended formatters should render output correctly';
}

sub default_formatter {
    my $self = shift;
    return $self->class_to_test->new(
        format => 'test',
    );
}

1;
