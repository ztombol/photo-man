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
use Test::Trap;

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
            # TODO: use this format when \r is taken care of.
            #format => "[      ] @>>>>>>> => %<< %>\r[@|||||]\n",
            format => "[      ] @>>>>>>> => %<< %>\n",
            width  => 40,
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

    # TODO: test for width and elastic fields.
}

sub attributes : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my $fmt = $self->default_formatter;
    my @want;
    my %default_attributes;
    
    # Getters.
    %default_attributes = (
        width => 40,
    );

    while (my ($attribute, $value) = each %default_attributes) {
        my $getter = "get_$attribute";
        can_ok $fmt, $getter;
        eq_or_diff $fmt->$getter(), $value,
            "getter for '$attribute' should be correct";
    }
    
    # Setters.
    $fmt->set_width( 80 );
    @want = (
        TCO::Output::Columnar::Field::Literal->new(
            string => "[      ] ",
        ),
        TCO::Output::Columnar::Field::Data->new(
            width     => 8,
            alignment => 'right',
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => " => ",
        ),
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 3,
            width     => 34,
            alignment => 'left',
            truncator => TCO::String::Truncator->new(
                method => 'end',
                length => 34,
            ),
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => " ",
        ),
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 2,
            width     => 23,
            alignment => 'right',
            truncator => TCO::String::Truncator->new(
                method => 'beginning',
                length => 23,
            ),
        ),
        #TCO::Output::Columnar::Field::Literal->new(
        #    string => "\r[",
        #),
        #TCO::Output::Columnar::Field::Data->new(
        #    width     => 6,
        #    alignment => 'centre',
        #),
        TCO::Output::Columnar::Field::Literal->new(
            string => "\n",
        ),
        TCO::Output::Columnar::Field::Stop->new(),
    );
    eq_or_diff $fmt->_get_fields, \@want,
        "setting width should re-stretch elastic fields";
}

sub _parse_format : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my (@want, @have);

    # Literal field.
    @have = $class->_parse_format( "literal" );
    @want = (
        TCO::Output::Columnar::Field::Literal->new(
            string => "literal",
        ),
    );
    eq_or_diff \@have, \@want, "literal";


    #
    # Data
    #

    # Left aligned.
    @have = $class->_parse_format( "@<<<<" );
    @want = (
        TCO::Output::Columnar::Field::Data->new(
            width     => 5,
            alignment => 'left',
        ),
    );
    eq_or_diff \@have, \@want, "data: left aligned";

    # Centred.
    @have = $class->_parse_format( "@||||" );
    @want = (
        TCO::Output::Columnar::Field::Data->new(
            width     => 5,
            alignment => 'centre',
        ),
    );
    eq_or_diff \@have, \@want, "data: centred";

    # Right aligned.
    @have = $class->_parse_format( "@>>>>" );
    @want = (
        TCO::Output::Columnar::Field::Data->new(
            width     => 5,
            alignment => 'right',
        ),
    );
    eq_or_diff \@have, \@want, "data: right aligned";

    # Truncated at the beginning.
    @have = $class->_parse_format( "@...<" );
    @want = (
        TCO::Output::Columnar::Field::Data->new(
            width     => 5,
            alignment => 'left',
            truncator => TCO::String::Truncator->new(
                method => 'beginning',
                length => 5,
            ),
        ),
    );
    eq_or_diff \@have, \@want, "data: truncated at the beginning";

    # Truncated at the end.
    @have = $class->_parse_format( "@<..." );
    @want = (
        TCO::Output::Columnar::Field::Data->new(
            width     => 5,
            alignment => 'left',
            truncator => TCO::String::Truncator->new(
                method => 'end',
                length => 5,
            ),
        ),
    );
    eq_or_diff \@have, \@want, "data: truncated at the end";


    #
    # Elastic data.
    #

    # Left aligned.
    @have = $class->_parse_format( "%<<<<" );
    @want = (
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 5,
            width     => 1,
            alignment => 'left',
        ),
    );
    eq_or_diff \@have, \@want, "elastic data: left aligned";

    # Centred.
    @have = $class->_parse_format( "%||||" );
    @want = (
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 5,
            width     => 1,
            alignment => 'centre',
        ),
    );
    eq_or_diff \@have, \@want, "elastic data: centred";

    # Right aligned.
    @have = $class->_parse_format( "%>>>>" );
    @want = (
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 5,
            width     => 1,
            alignment => 'right',
        ),
    );
    eq_or_diff \@have, \@want, "elastic data: right aligned";

    # Truncated at the beginning.
    @have = $class->_parse_format( "%...<" );
    @want = (
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 5,
            width     => 1,
            alignment => 'left',
            truncator => TCO::String::Truncator->new(
                method => 'beginning',
                length => 5,
            ),
        ),
    );
    eq_or_diff \@have, \@want, "elastic data: truncated at the beginning";

    # Truncated at the end.
    @have = $class->_parse_format( "%<..." );
    @want = (
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 5,
            width     => 1,
            alignment => 'left',
            truncator => TCO::String::Truncator->new(
                method => 'end',
                length => 5,
            ),
        ),
    );
    eq_or_diff \@have, \@want, "elastic data: truncated at the end";
}

sub _parse_control : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my (@want, @have);

    # Format only.
    @have = @{$class->_parse_control(
        format  => "@>>>>>>> = %< / %<\n",
        control => "                   ",
    )};
    @want = (
        TCO::Output::Columnar::Field::Data->new(
            width     => 8,
            alignment => 'right',
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => " = ",
        ),
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 2,
            width     => 1,
            alignment => 'left',
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => " / ",
        ),
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 2,
            width     => 1,
            alignment => 'left',
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => "\n",
        ),
        TCO::Output::Columnar::Field::Stop->new(),
    );
    eq_or_diff \@have, \@want, "a single group should be parsed correctly";

    # Format and control.
    @have = @{$class->_parse_control(
        format  => "@>>>>>>> = %< / %<\n",
        control => "             ^     ",
    )};
    @want = (
        TCO::Output::Columnar::Field::Data->new(
            width     => 8,
            alignment => 'right',
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => " = ",
        ),
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 2,
            width     => 1,
            alignment => 'left',
        ),
        TCO::Output::Columnar::Field::Stop->new(),
        TCO::Output::Columnar::Field::Literal->new(
            string => " / ",
        ),
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 2,
            width     => 1,
            alignment => 'left',
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => "\n",
        ),
        TCO::Output::Columnar::Field::Stop->new(),
    );
    eq_or_diff \@have, \@want, "multiple groups should be parsed correctly";
}

sub _stretch : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my @want;
    my $fmt;

    # Static and elastic.
    $fmt = $class->new(
        format => "@>>>>>>> = %< %<\n",
        width  => 40,
    );
    @want = (
        TCO::Output::Columnar::Field::Data->new(
            width     => 8,
            alignment => 'right',
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => " = ",
        ),
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 2,
            width     => 13,
            alignment => 'left',
            truncator => TCO::String::Truncator->new(
                method => 'end',
                length => 13,
            ),
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => " ",
        ),
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 2,
            width     => 14,
            alignment => 'left',
            truncator => TCO::String::Truncator->new(
                method => 'end',
                length => 14,
            ),
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => "\n",
        ),
        TCO::Output::Columnar::Field::Stop->new(),
    );
    eq_or_diff $fmt->_get_fields, \@want,
        "elastic fields should be stretched correctly";

    # Static only.
    $fmt = $class->new(
        format => "@>>>>>>> = @<<< @<<<\n",
    );
    @want = (
        TCO::Output::Columnar::Field::Data->new(
            width     => 8,
            alignment => 'right',
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => " = ",
        ),
        TCO::Output::Columnar::Field::Data->new(
            width     => 4,
            alignment => 'left',
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => " ",
        ),
        TCO::Output::Columnar::Field::Data->new(
            width     => 4,
            alignment => 'left',
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => "\n",
        ),
        TCO::Output::Columnar::Field::Stop->new(),
    );
    eq_or_diff $fmt->_get_fields, \@want,
        "a static only format should not be stretched";
}

sub append  : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my @want;
    my $fmt;
    
    # Append without stop.
    $fmt = $class->new(
        format  => "[      ]",
    );
    $fmt->append(
        format  => " @<<<<<<<",
    );
    @want = (
        TCO::Output::Columnar::Field::Literal->new(
            string => "[      ]",
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => " ",
        ),
        TCO::Output::Columnar::Field::Data->new(
            width     => 8,
            alignment => 'left',
        ),
        TCO::Output::Columnar::Field::Stop->new(),
    );
    eq_or_diff $fmt->_get_fields, \@want,
        "appending should be correct when trailing stop is removed";

    # Append with stop.
    $fmt = $class->new(
        format  => "[      ]",
    );
    $fmt->append(
        format  => " @<<<<<<<",
        control => "^        ",
    );
    @want = (
        TCO::Output::Columnar::Field::Literal->new(
            string => "[      ]",
        ),
        TCO::Output::Columnar::Field::Stop->new(),
        TCO::Output::Columnar::Field::Literal->new(
            string => " ",
        ),
        TCO::Output::Columnar::Field::Data->new(
            width     => 8,
            alignment => 'left',
        ),
        TCO::Output::Columnar::Field::Stop->new(),
    );
    eq_or_diff $fmt->_get_fields, \@want,
        "appending should be correct when trailing stop is preserved";

    # Stretch elastic fields after appending.
    $fmt = $class->new(
        format  => "[      ] %<<<",
        width   => 20,
    );
    $fmt->append(
        format     => " %<<<<<<<",
        control    => "         ",
    );
    @want = (
        TCO::Output::Columnar::Field::Literal->new(
            string => "[      ] ",
        ),
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 4,
            width     => 3,
            alignment => 'left',
            truncator => TCO::String::Truncator->new(
                method => 'end',
                length => 3,
            ),
        ),
        TCO::Output::Columnar::Field::Literal->new(
            string => " ",
        ),
        TCO::Output::Columnar::Field::Data::ElasticData->new(
            ratio     => 8,
            width     => 7,
            alignment => 'left',
            truncator => TCO::String::Truncator->new(
                method => 'end',
                length => 7,
            ),
        ),
        TCO::Output::Columnar::Field::Stop->new(),
    );
    eq_or_diff $fmt->_get_fields, \@want,
        "appending should re-stretch elastic fields";
}

sub print : Tests {
    my $self = shift;
    my $class = $self->class_to_test;
    my $fmt;

    #
    # Common
    #

    # Print until first stop.
    $fmt = $class->new(
        format  => "filename = @<",
        control => "        ^    ",
    );
    trap { $fmt->print() };
    $trap->stdout_is( 'filename', "printing without data until the first stop field should be correct" );


    #
    # Static.
    #
    
    # Print until first stop.
    $fmt = $class->new(
        format  => "filename = @<",
    );
    trap { $fmt->print() };
    $trap->stdout_is( 'filename = ', "(static) printing without data until the first data field should be correct" );
    
    # Print until first stop.
    $fmt = $class->new(
        format  => "filename = @< ... done!",
    );
    trap { $fmt->print('tako.jpeg') };
    $trap->stdout_is( 'filename = tako.jpeg ... done!', "(static) printing with data until the first stop field should be correct" );
    
    # Print until first stop.
    $fmt = $class->new(
        format  => "filename = @<  size = @<",
    );
    trap { $fmt->print('tako.jpeg') };
    $trap->stdout_is( 'filename = tako.jpeg  size = ', "(static) printing with data until the first data field should be correct" );
    

    #
    # Elastic.
    #
    
    # Print until first stop.
    $fmt = $class->new(
        format  => "filename = %<",
        width   => 20,
    );
    trap { $fmt->print() };
    $trap->stdout_is( 'filename = ', "(elastic) printing without data until the first data field should be correct" );
    
    # Print until first stop.
    $fmt = $class->new(
        format  => "filename = %<",
        width   => 20,
    );
    trap { $fmt->print('tako.jpeg') };
    $trap->stdout_is( 'filename = tako.jpeg', "(elastic) printing with data until the first stop field should be correct" );
    
    # Print until first stop.
    $fmt = $class->new(
        format  => "filename = %<  size = %<",
        width   => 40,
    );
    trap { $fmt->print('tako.jpeg') };
    $trap->stdout_is( 'filename = tako.jpeg   size = ', "(elastic) printing with data until the first data field should be correct" );


    #
    # Multiple lines.
    #

    # Multiple lines.
    $fmt = $class->new(
        format  => "filename = %< [@|||||]\n",
        width   => 35,
    );
    trap { $fmt->print('tako.jpeg', 'done', 'crab.jpg', 'done') };
    $trap->stdout_is( "filename = tako.jpeg      [ done ]\nfilename = crab.jpg       [ done ]\n", "(elastic) printing with data until the first data field should be correct" );
}

1;
