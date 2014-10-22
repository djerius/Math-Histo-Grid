#! perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::Deep;
use Data::Dumper;

use Math::BigFloat;

local $Data::Dumper::Indent = 0;

use Math::Histo::Grid::Constants -limit;

use Math::Histo::Grid::Types -types;

for my $tpars (
    [ BigNum         => q/x/ ],
    [ BigInt         => q/x/ ],
    [ BigPositiveNum => q/x/ ],
    [ BigPositiveNum => 0 ],
    [ BigPositiveNum => -1 ],
    [ BigPositiveInt => q/x/ ],
    [ BigPositiveInt => 0 ],
    [ BigPositiveInt => -1 ],
    [ BigPositiveInt => 1.1 ],
  )
{

    my ( $type, $exp ) = @$tpars;

    isnt( exception { $type->()->assert_coerce( $exp ) },
        undef, "bad $type: $exp" );
}

for my $tpars (
    [ BigNum         => 1.1 ],
    [ BigNum         => 0 ],
    [ BigNum         => -1.1 ],
    [ BigInt         => 2 ],
    [ BigInt         => 0 ],
    [ BigInt         => -2 ],
    [ BigPositiveNum => 1.1 ],
    [ BigPositiveInt => 1 ],
  )
{

    my ( $type, $exp ) = @$tpars;

    my ( $ex, $got );
    {
        no strict 'refs';
        is( $ex = exception { $got = $type->()->assert_coerce( $exp ) },
            undef, "good $type: $exp" );
    }
    my $class = $type =~ /Num/ ? 'Math::BigFloat' : 'Math::BigInt';
    isa_ok( $got, $class, 'class' );
}

for my $value ( qw/ LIMIT_HARD LIMIT_SOFT / ) {

    no strict 'refs';
    my $got;
    is( exception { $got = LimitState->assert_return( $value->() ) },
        undef, "type $value", );
    is( $got, $value->(), "value $value" );

}

for my $value ( 'snack', -2, 5 ) {

    isnt( exception { LimitState->assert_valid( $value ) },
        undef, "type $value", );

}

for ( [ [ 0, 0 ] => [ 0, 0 ] ],
      [ [ 0, 0.3 ] => [ 0, 0.3 ] ],
      [ 2 => [ 2, 0.5 ] ]
    ) {

    my ( $in, $exp ) = @$_;

    my $ins = Dumper( $in );
    my $got;
    is( exception { $got = Alignment->assert_coerce( $in ) },
        undef, "coerce: $ins" );
    $exp = [ map { Math::BigFloat->new($_) } @$exp ];
    cmp_deeply( $got, $exp, "value: $ins" );
}

done_testing;
