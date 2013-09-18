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


# An object oriented solution to print data in a columnar fashion. It differs
# from Perl's built-in `format' by allowing the user to iteratively build the
# output cell by cell, instead of printing complete lines.
package TCO::Output::Columnar::Format;

use Moose;
use MooseX::FollowPBP;
use namespace::autoclean;
use Carp 'croak';

use TCO::Output::Columnar::Field::Data;
use TCO::Output::Columnar::Field::Literal;
use TCO::Output::Columnar::Field::Stop;

our $VERSION = '0.1';
$VERSION = eval $VERSION;

# Array of output fields.
has 'fields' => ( 
    is       => 'rw',
    isa      => 'ArrayRef',
    required => 1,
    reader   => '_get_fields',
    writer   => '_set_fields',
);

# Index of field to print next.
has 'position' => (
    is       => 'rw',
    isa      => 'Int',
    default  => 0,
    reader   => '_get_position',
    writer   => '_set_position',
    trigger  => sub {
        my ( $self, $position, $old_position ) = @_;
        
        # Set position back to zero if it would be out of bounds.
        if ( $position >= scalar @{$self->_get_fields} ) {
            $self->_set_position(0);
        }
    }
);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my $args_ref;

    # Accept attributes in a hash or a hashref.
    if ( @_ == 1 && (ref $_[0] eq 'HASH') ) { $args_ref = shift; }
    else                                    { $args_ref = {@_};  }

    my $format  = $args_ref->{format}  || croak "Attribute (format) is required at constructor ${class}::new";
    my $control = $args_ref->{control} || ' ' x length $format;

    # Produce fields that corresponds to the format described in format and control.
    my $fields = $class->_parse_control( $format, $control );

    return $class->$orig( fields => $fields );
};

# Creates an array of fields by parsing the format and optinally the control
# string. The format string describes the visual format of the output. The
# optional control string lets the user to control the way the format string
# is parsed.
#
# The following control characters are supported:
#   ^ (caret)
#     Divides the format string into parts that are parsed separately. A caret
#     or the first character of the control string denotes the beginning and
#     the last character before the next caret or the end of the string denotes
#     the end of a part. This feature can be used to divide the output into
#     logical parts and control how many fields are output at once.
#
#     For example, consider the following format that accepts two variables
#     when output.
#
#       $format = "distance = @>>>>> cm (@>>>>> in)\n"
#
#     By default it is parsed as this.
#
#       literal   "distance ="
#       data      6 chars, right aligned
#       literal   " cm ("
#       data      6 chars, right aligned
#       literal   " in )\n"
#
#     When output, it looks like this.
#
#       $out->print(25.4);   "distance =   24.4 cm ("
#       $out->print(10);                           "    10 in)\n"
#
#     Note, that after supplying the first piece of data it prints the opening
#     parenthesis as well that logically belongs to the second data field.
#
#     To modify the behavior of the printing algorithm, one can use group
#     separators, caret symbols, in the control string to logically group the
#     fields.
#
#       $format  = "distance = @>>>>> cm (@>>>>> in)\n"
#       $control = "                     ^           "
#
#     Note: The line feed character sequence '\n' is technically one character
#     long. This implies that the control string should be one character
#     shorter than the format. However extra whitespace at the end of the
#     control string is ignored by the constructor and thus is not an error. Be
#     careful however when escaped characters appear anywhere before the last
#     character of the format string as it can produce unwanted output.
#
# @param [IN] $1  format string
# @param [IN] $2  control string
# @returns        reference to array of fields
sub _parse_control {
    my $class = shift;
    my $fmt_str = shift;
    my $ctrl_str = shift;

    # Regex extracting a group from the control string.
    my $ctrl_regex = qr{
        (?<group>
    	    (\^|\A)  # beginning of line or ^
            [^^]+    # at least one character before the next group
        )
    }x;

    # Extract format string for each field group and retrieve the corresponding
    # fields.
    my @fields;
    my $grp_start = 0;  # First character of format string in current group.

    while ( $ctrl_str =~ /$ctrl_regex/g ) {
        # Extract the next portion of the format string to parse.
        my $grp_len = length $1;
        my $grp_str = substr( $fmt_str, $grp_start, $grp_len );

        # Parse extracted format string and append new fields.
        push @fields, $class->_parse_format( $grp_str );

        # There is a stop field after every group.
        push @fields, TCO::Output::Columnar::Field::Stop->new();

    	$grp_start += $grp_len;
    }

    # Return reference to array.
    return \@fields;
}

# Returns an array of fields that represent the format specfied by the
# formatting string.
#
# There are two types of fields recognised. *Literal fields* that produce a
# constant string to be outputed, and *data fields* that are placeholders for
# data that will be specified later.
#
# Data fields have 3 properties. Alignment that specifies how to pad data when
# it's shorter than the field. Width, specifying the maximum number of
# characters the data can take up. And truncation, that specifyies which part
# of the data to omit when the data is wider than the available space.
#
# @param [in] $1  format string
# returns         array of fields
sub _parse_format {
    my $self = shift;
    my $fmt_str = shift;
    my @fields;

    # Regex to match the different fields.
    my $fmt_regex = qr{
        (?<f_d>@                # data field
            (?<t_b>\.\.\.)?     #    truncate at the beginning
            (                   #    alignment:
                (?<a_l><+)  |   #        left, or
                (?<a_c>\|+) |   #        centre, or
                (?<a_r>>+)      #        right
            )                   #
            (?<t_e>\.\.\.)?     #    truncate at the end
        ) |                     # or
        (?<f_l>[^@]+)           # literal field
    }x;
    
    # Parse each field group separately.
    while ( $fmt_str =~ /$fmt_regex/g ) {
        # Instantiate new field.
        my $new_field;

        if ( defined $+{ f_l } ) {
            # Literal field matched.
            $new_field = TCO::Output::Columnar::Field::Literal->new(
                string => $+{ f_l },
            );
        }
        else {
            # Data field matched.
            my %align = (
                a_l => 'left',
                a_c => 'centre',
                a_r => 'right',
            );
            my %trunc = (
                t_b => 'beginning',
                t_e => 'end',
            );

            # Alignment.
            foreach my $al (qw{ a_l a_c a_r }) {
                next if not defined $+{ $al };

                my $length = length $+{ f_d };

                # Truncator.
                my $truncator;
                foreach my $tr (qw{ t_b t_e }) {
                    next if not defined $+{ $tr };

                    $truncator = TCO::String::Truncator->new(
                        method => $trunc{ $tr },
                        length => $length,
                    );
                    last;
                }

                # Instantiate data field.
                $new_field = TCO::Output::Columnar::Field::Data->new(
                    alignment => $align{ $al },
                    width     => $length,
                );

                # Set truncator if any.
                $new_field->set_truncator( $truncator ) if defined $truncator;

                last;
            }
        }

        # Add new field to array.
        push @fields, $new_field;
    }
    
    # Return array of fields.
    return @fields;
}

# Appends new fields to the end of a formatter. Accepts the same parameters as
# the *_parse_control* subroutine. By default the first group of the new fields
# are joined with the last field group of the existing fields (i.e. the
# trailing stop is removed). If you want the first group of the new fields to
# be in a separate group and thus preserve the stop between the existing and
# the new fields, specify a caret ('^') as the first character in the control
# string of the appended fields. This will make sure that the trailing stop is
# left intact.
#
# For example, consider the following configuration.
#
#   my $fmt = TCO::Output::Columnar::Format->new(
#       format  => "@>>>>>> = @<<<<<<<<<<<",
#   );
#
#   $fmt->append(
#       format  => " (@>>>>>)\n",
#   );
#
# The append will cause the last stop be removed and the existing and new
# groups to be merged. Thus, the output of the commands below.
#
#   $fmt->print('name', 'Jake Green');  "   name = Jake Green   ("
#   # more code...
#   $fmt->print('Jericho');             "   name = Jake Green   (Jericho)\n"
#
# If the two commands would follow each other immediately there would be no
# problem. However, if there is considerable delay between executing them, the
# output will look funny as above.
#
# To overcome this ugly bug, specify a control string starting with a caret for
# the appended fields, like this.
#
#   $fmt->append(
#       format  => " (@>>>>>)\n",
#       control => "^         ",
#   );
#
# Now the output will look okay even if there is a noticable delay between the
# execution of the commands.
#
#   $fmt->print('name', 'Jake Green');  "@>>name = Jake Green  "
#   # more code...
#   $fmt->print('Jericho');             "@>>name = Jake Green   (Jericho)\n"
#
#
# @param [IN] $1  format string
# @param [IN] $2  control string
sub append {
    my $self = shift;
    my $args_ref;

    # Accept attributes in a hash or a hashref.
    if ( @_ == 1 && (ref $_[0] eq 'HASH') ) { $args_ref = shift; }
    else                                    { $args_ref = {@_};  }

    my $format  = $args_ref->{format}  || croak "Attribute (format) is required at " . blessed($self) . "::append";
    my $control = $args_ref->{control} || ' ' x length $format;

    # Remove trailing stop if the control string does not start with a caret.
    if ( substr($control, 0, 1) ne '^' ) {
        $self->_remove_last_stop;
    }

    # Parse format and control to get new fields.
    my $fields = $self->_parse_control( $format, $control );

    # Append new fields.
    push @{$self->_get_fields}, @{$fields};
}

# Removes the last field of the array if that is a stop field. Leaves the field
# array untouched otherwise.
sub _remove_last_stop {
    my $self = shift;

    if ( (@{$self->_get_fields}[-1])->get_type eq 'stop' ) {
        pop $self->_get_fields;
    }
}

# Returns the next field to be processed (i.e field at the current position).
# After invocation the returned field is considered to be consumed and the
# position will be incremented. This means that repeatedly calling this
# subroutine will return the field next in line without explicitely setting the
# position attribute.
#
# @returns the next field in the field array
sub _get_next_field {
    my $this = shift;

    my $position = $this->_get_position;
    $this->_set_position( $this->_get_position + 1 );
    return $this->_get_fields->[$position];
}

# Returns the type of the next field. This subroutine peeks at the next field
# and does not cause the position pointer to jump to the next field.
#
# @returns the type of the next field
sub _type_of_next {
    my $self = shift;
    return (@{$self->_get_fields}[ $self->_get_position ])->get_type;
}

# Prints the supplied data formatted according to the fields of the formatter.
# Mulitple pieces of data can be supplied that will be used in FIFO order and
# fed into the data fields. Fields are processed until the first stop or data
# field is encountered after the last piece of data is consumed. When called
# without data, the subroutine will print literal fields up to the next data or
# stop field.
#
# @param [in] @data  data to format
sub print {
    my ( $self, @data ) = @_;
    
    # Process fields until we encounter the first stop or data field after
    # consuming all user supplied data.
    while ( @data != 0
         || ($self->_type_of_next ne 'data' && $self->_type_of_next ne 'stop') ) {

        my $field = $self->_get_next_field;

        # Print data and literal fields.
        if ( $field->get_type eq 'data' ) {
            print $field->as_string( shift @data );
        }
        elsif ( $field->get_type eq 'literal' ) {
            print $field->as_string;
        }
    }
}

# Reset the formatter back to the beginning of the field array and print a line
# feed as well. This subroutine can be used to ignore the remaining fields in
# the formatter, and start printing a new line.
sub reset {
    my $self = shift;
    $self->_set_position( 0 );
    print "\n";
}

__PACKAGE__->meta->make_immutable;

1;
