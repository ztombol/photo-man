package TCO::Output::Columnar::Types;

use Moose::Util::TypeConstraints;

subtype 'TCO::Output::Columnar::Types::FieldWidth'
    => as      'Int'
    => where   { $_ > 0 }
    => message { "Field width must be a positive integer, you specified $_" };

subtype 'TCO::Output::Columnar::Types::FieldAlignment'
    => as      'Str'
    => where   { $_ eq 'left' || $_ eq 'centre' || $_ eq 'right' }
    => message { "Field alignment must be one of `left', `centre' or `right', you specified $_" };
