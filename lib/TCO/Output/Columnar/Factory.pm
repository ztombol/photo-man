# An object oriented solution to print data in a columnar fashion. It differs
# from Perl's built-in `format' by allowing the user to iteratively build the
# output cell by cell, instead of printing complete lines.

package TCO::Output::Columnar::Factory;

use v5.14; # given/when
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
    required => 1,
    reader   => '_get_position',
    writer   => '_set_position',
    trigger  => sub {
        # Set position back to zero if it would be out of bounds.
        my ( $self, $position ) = @_;

        if ( $position >= scalar @{$self->_get_fields} ) {
            $self->_set_position(0);
        }
    }
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my $arg_for;

    if ( @_ == 1 && ref $_[0] ) {
        # Hashref
        $arg_for = $_[0];
    } else {
        # Hash
#        my ( %arg ) = @_;
#        my $arg_for = \%arg;
    }

    my $format  = $arg_for->{format};
    my $control = $arg_for->{control} || ' ' x length $format;

    my $fields_ref = $class->_initialise( $format, $control );
    return $class->$orig( fields => $fields_ref );
};

# Constructor. Creates a new object from the formatting string.
#
# @param [IN] $1  class being instantiated
# @param [IN] $2  string describing the output format
# @returns        reference to array of fields
sub _initialise {
    my $class = shift;

    my $format_str = shift;
    my $control_str = shift;

    # Parse the format string describing how data should be formatted. Divides
    # the format string into groups and parses them one by one. This produces
    # an array of `data fields' (where user data will be filled in), literals
    # (e.g. borders and separators), and `group boundries' (separating field
    # groups).
    my @fields;

    # Field groups starts at this offset in format string.
    my $start = 0;
    while ( $control_str =~ /
        (?<group>
            (\^|\A) # beginneing of line or separator
            [^^]+   # at least one character except the separator 
        )
        (?=\^|\Z)   # followed the end of the line or separator 
        /xg)
    {
        # Extract substring decribing the current group.
        my $group_width = length $+{group};
        my $group_str = substr( $format_str, $start, $group_width );

        # Increment substring offset for the next group.
        $start += $group_width;

        # Parse each field in the group formatting string.
        while ( $group_str =~ /
            @(                    # date field:
                (?<left>\<+)   |  #   left justified, or
                (?<centre>\|+) |  #   centred, or
                (?<right>\>+)     #   right justified
            ) |                   # or
            (?<literal>[^@]*)     # literal field
            /xg)
        {
            if ( not $+{literal} ) {
                # This is a data field.
                foreach ( qw(left centre right) ) {
                    # Find out which alignment we are dealing with.
                    next if ( not $+{$_} );
                    push @fields, TCO::Output::Columnar::Field::Data->new({
                        alignment => $_,
                        width     => ( length $+{$_} ) + 1,
                    });
                }
            }
            else {
                # This is a literal.
                push @fields, TCO::Output::Columnar::Field::Literal->new({
                    string => $+{literal},
                });
            }
        }

        # Append group boundary.
        push @fields, TCO::Output::Columnar::Field::Stop->new();
    }

    # Uncomment the following block to display the field array.
    #{
    #    require Data::Dumper;
    #    print Data::Dumper->Dump([\@fields], [qw(fields)]);
    #}

    # Return reference to array.
    return \@fields;
}

# Appends additional fields to the output object.
#
# FIXME: If you have already used the object to output fields, one field will
#        be skipped.
sub append_stop {
    my $self = shift;

    my $arg_for;

    if ( @_ == 1 && ref $_[0] ) {
        # Hashref
        $arg_for = $_[0];
    } else {
        # Hash
#        my ( %arg ) = @_;
#        my $arg_for = \%arg;
    }

    my $format  = $arg_for->{format};
    my $control = $arg_for->{control} || ' ' x length $format;

    # Produce new fields.
    my $fields_ref = $self->_initialise( $format, $control );

    # Add new fields.
    push @{$self->_get_fields}, @{$fields_ref};
}

# Same as append, but it also removes the trailing stop before appending the
# new fields.
sub append {
    my $self = shift;
    
    my $arg_for;

    if ( @_ == 1 && ref $_[0] ) {
        # Hashref
        $arg_for = $_[0];
    } else {
        # Hash
#        my ( %arg ) = @_;
#        my $arg_for = \%arg;
    }

    my $format  = $arg_for->{format};
    my $control = $arg_for->{control} || ' ' x length $format;

    $self->remove_last_stop;
    $self->append_stop({
        format  => $format,
        control => $control,
    });
}

sub remove_last_stop {
    my $self = shift;
    pop $self->_get_fields;
}

# Returns the field at the current position and increments the `position' so
# that every time you call this method you will automatically get the next
# field to process without explicitely incrementing `position'.
#
# @returns  (hash ref)
sub _get_next_field {
    my $this = shift;

    my $position = $this->_get_position;
    $this->_set_position( $this->_get_position + 1 );
    return $this->_get_fields->[$position];
}


# Prints output fields until it hits the first stop or data field after
# consuming the last data item.
sub print {
    my ( $self, @data_arr ) = @_;

    while ( 1 ) {
        my $field = $self->_get_next_field;

        if ( $field->get_type eq 'data' ) {
            if (! @data_arr) {
                # Stop here if we do not have any more data to feed into the
                # next data field.
                # TODO: this is ugly
                $self->_set_position( $self->_get_position - 1);
                last;
            }
            print $field->as_string( shift @data_arr );
        }
        elsif ( $field->get_type eq 'literal' ) {
            print $field->as_string();
        }
        elsif ( $field->get_type eq 'stop' && ! @data_arr) {
            # We hit a stop field and there is no more data to print so let's
            # stop here.
            # TODO: this is ugly
            $self->_set_position( $self->_get_position - 1);
            last;
        }
    }
}

# Reset to the beginning of the field array and print a line feed.
sub reset {
    my $self = shift;
    $self->_set_position( 0 );
    print "\n";
}

__PACKAGE__->meta->make_immutable;

1;