#
# Copyright (C)  2013  Zoltan Vass <zoltan.tombol (at) gmail (dot) com>
#

#
# This file is part of photo-man.
#
# photo-man is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# photo-man is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with photo-man.  If not, see <http://www.gnu.org/licenses/>.
#


package TestsFor::TCO::Output::Columnar::Format;

use Test::Class::Most
    parent      =>'TestsFor',
    attributes  => [qw(default_formatter)];

use Capture::Tiny qw(capture_merged);

sub startup : Tests(startup) {
    my $self  = shift;
    my $class = ref $self;

    # First call the parent method.
    $self->next::method;

    # Startup code goes here...
}

sub setup : Tests(setup) {
    my $self  = shift;
    my $class = $self->class_to_test;

    # First call the parent method.
    $self->next::method;

    # Instantiate default formatter object.
    $self->default_formatter(
        $class->new(
            format => "[      ] @>>>>>>> => @<<<<<<<\r[@|||||]\n",
        )
    );
}

sub teardown : Tests(teardown) {
    my $self = shift;

    # Teardown code goes here...

    # Finally, call parent method.
    $self->next::method;
}

sub shutdown : Tests(shutdown) {
    my $self = shift;

    # Shutdown code goes here...

    # Finally, call parent method.
    $self->next::method;
}

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
        ], [
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
        ], [
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
        ], [
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

1;
