#! perl

package Math::Histo::Grid::Types;

use Math::BigInt;
use Math::BigFloat;
use Type::Utils;
use Types::Standard qw[ Num Int Enum Tuple Any ];
use Types::Common::Numeric qw[ PositiveNum PositiveOrZeroNum PositiveInt ];

use Type::Library -base, -declare => qw(
  BigNum
  BigPositiveNum
  BigPositiveOrZeroNum
  BigInt
  BigPositiveInt
  LimitState
  Align
);


use Math::Histo::Grid::Constants -limit;

class_type BigNum,
  {
    class => 'Math::BigFloat',
    message { 'Not a number or a Math::BigFloat' },
  };

coerce BigNum, from Num, via {
    Math::BigFloat->new( $_ );
};

declare BigPositiveNum, as BigNum,
  where { $_ > 0 },
  message { BigNum->validate( $_ ) or "$_ is not greater than zero" },
  coercion => 1;

coerce BigPositiveNum,
  from PositiveNum,
  via { Math::BigFloat->new( $_ ) };

declare BigPositiveOrZeroNum, as BigNum,
  where { $_ >= 0 },
  message { BigNum->validate( $_ ) or "$_ is not greater than or equal to zero" },
  coercion => 1;

coerce BigPositiveOrZeroNum,
  from PositiveOrZeroNum,
  via { Math::BigFloat->new( $_ ) };

class_type BigInt,
  {
    class => 'Math::BigInt',
    message { 'Not an integer or a Math::BigInt' },
  };

coerce BigInt, from Int, via {
    Math::BigInt->new( $_ );
};

declare BigPositiveInt, as BigInt,
  where { $_ > 0 },
  message { BigInt->validate( $_ ) or "$_ is not greater than zero" },
  coercion => 1;

declare LimitState, as Enum [ LIMIT_HARD, LIMIT_SOFT ];

declare Alignment,
  as Tuple [ BigNum, BigPositiveOrZeroNum ],
  where { $_->[1] < 1 },
  coercion => 1;

coerce Alignment,
  from Num,
  via { [ Math::BigFloat->new($_), Math::BigFloat->new(0.5) ] };

1;
