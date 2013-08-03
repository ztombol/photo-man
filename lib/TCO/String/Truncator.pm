package TCO::String::Truncator;

use Moose;
use MooseX::FollowPBP;
use namespace::autoclean;
use Carp 'croak';

our $VERSION = '0.1';
$VERSION = eval $VERSION;

# Method of truncation specifying how and which parts to cut.
has 'method' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    reader   => '_get_method',
);

# Maximum length of the truncated string.
has 'length' => (
    is       => 'ro',
#    isa      => 'TCO::String::Types::NonNegativeInteger',
    isa      => 'Int',
    required => 1,
    reader   => '_get_length',
);

# String where cutting is allowed. If set to the empty string '' truncation can
# happen anywhere (default).
has 'delimiter' => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
    reader  => '_get_delimiter'
);

# String to use in place of the cut parts.
has 'ellipsis' => (
    is      => 'ro',
    isa     => 'Str',
    default => '...',
    reader  => '_get_ellipsis',
);

# Truncates a string according to the parameters passed to the constructor.
sub truncate {
    my $self = shift;
    my $string = shift;

    my $len_string = length $string;
    if ( $self->_get_length >= $len_string ) {
        # String is short enough, no need to truncate.
        return $string;
    }

    # NOTE: This convoluted way of truncating strings was just a *fun* little
    #       excecise. In the near future this will be replaces with an
    #       implementation based on regular expressions.

    # The problem we need to solve is to find the first (last) delimiter
    # string whose end falls within the substring whose length is the
    # maximum possible.
    #
    # The trick here is to figure out character indices while accounting
    # for all variables.
    #
    # In case of cutting excess characters at the end of the string, only the
    # ellipsis that's influences the starting position of the search. We need
    # to shift the start of the search by the length of the ellipsis towards
    # the beginning of the string.
    #
    # If we are cutting at the beginning, the picture is a bit more complicated
    # and bot the ellipsis and delimiter strings need to be taken into account.
    # The ellipsis needs to fit within the tuncated string width. So we
    # have to shorten the searched area by the length of the ellipsis. But
    # the delimiter could start inside or even before (after) the region
    # occupied by the ellipses. Accordingly, the searched are have to be
    # expanded.
    #
    # After the start of the delimiter is found, we add (substract) the
    # length of the delimiter, as it will not be included in the truncated
    # string. Then use this corrected position as the start (end) to create
    # a substring and append (prepend) the ellipsis.
    #
    #
    # EXAMPLE:
    # --------
    #
    # Here's an example where we are looking for a maximum 16 characters
    # wide truncation at the beginning with 3 dots as ellipsis, and we are
    # allowed to cut at every space.
    #
    # Visally, it looks like this.
    #
    #   ellipsis  = '...'
    #   delimiter = ' '
    #
    #  [---------------- 44 chars ----------------]
    #                              [-- 16 chars --]
    # "The quick brown fox jumps over the lazy dog."
    #                              ...               +3 for ellipses
    #                                 ^              +1 for delimiter
    # 
    # And now the math.
    #
    #   $offset = 3 - (1 - 1) = 3
    #
    # The -1 is there to compensate for the fact that index (rindex)
    # performs an inclusive search and starts from the specified position.
    #
    #   $from   = 44 - 16 - 1 + 3 = 30
    #
    # So the search starts at index 30 (indexed from zero, of course). To
    # the index returned by the search will have to be added the length of
    # the delimiter to excluded it from the final result.
    #
    # Finally we concatenate the ellipsis and the extracted substring.
    #
    #   $extracted =  "..." . "the lazy dog."
    #

    my $len_delim = length $self->_get_delimiter;
    my $len_ellip = length $self->_get_ellipsis;

    if ( $self->_get_method eq 'end' ) {
        # Cut the excess at the end.
        my $offset = $len_ellip;
        my $from = ($self->_get_length) - $offset;
        my $cut_at = rindex($string, $self->_get_delimiter, $from);
        my $extracted = substr $string, 0, $cut_at;

        return $extracted . $self->_get_ellipsis;
    }
    elsif ( $self->_get_method eq 'beginning' ) {
        # Cut the excess at the beginning.
        my $offset = $len_ellip - ( $len_delim - 1);
        my $from = ($len_string - $self->_get_length - 1) + $offset;
        my $cut_at = index($string, $self->_get_delimiter, $from) + $len_delim;
        my $extracted = substr $string, $cut_at;

        return $self->_get_ellipsis . $extracted;
    }
}

__PACKAGE__->meta->make_immutable;

1;

