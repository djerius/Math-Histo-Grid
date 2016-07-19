#! perl

use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Fatal;

use Set::Partition;

use Math::Histo::Grid::Linear;

sub new { Math::Histo::Grid::Linear->new( @_ ) }

my $tol = 4e-15;

=pod

=item I<min>, I<max>, I<nbins>.

Extrema are as specified. The grid exactly covers the range.

=cut


{
    my %exp = ( min => 1, max => 10, nbins => 9 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min   => num( $exp{min} ),
            max   => num( $exp{max} ),
            nbins => $exp{nbins},
            binw  => array_each( num( 1, $tol ) ),
        ),
        "min, max, nbins",
    );

}

=pod

=item I<min>, I<range_width>, I<nbins>

=item I<max>, I<range_width>, I<nbins>

The extremum is as specified.  The grid exactly covers the range.

=cut

{
    my %exp = ( min => 1, range_width => 9, nbins => 9 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min   => num( $exp{min} ),
            max   => num( $exp{min} + $exp{range_width} ),
            nbins => $exp{nbins},
            binw  => array_each( num( 1, $tol ) ),
        ),
        "min, range_width, nbins",
    );

}

{
    my %exp = ( max => 10, range_width => 9, nbins => 9 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            max   => num( $exp{max} ),
            min   => num( $exp{max} - $exp{range_width} ),
            nbins => $exp{nbins},
            binw  => array_each( num( 1, $tol ) ),
        ),
        "max, range_width, nbins",
    );

}

=pod

=item I<min>, I<range_width>, I<binw>

=item I<max>, I<range_width>, I<binw>

The extremum is as specified. The number of bins is chosen
to minimally cover the specified range.

=cut

{
    my %exp = ( min => 1, range_width => 9, binw => 1.1 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min  => num( $exp{min} ),
            max  => num( 10.9 ),
            binw => array_each( num( $exp{binw}, $tol ) ),
        ),
        "min, range_width, binw",
    );

}

{
    my %exp = ( max => 10.9, range_width => 9, binw => 1.1 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            max  => num( $exp{max} ),
            min  => num( 1.0 ),
            binw => array_each( num( $exp{binw}, $tol ) ),
        ),
        "max, range_width, binw",
    );

}

=pod

=item I<min>, I<nbins>, I<binw>

=item I<max>, I<nbins>, I<binw>

The extremum is as specified.  The grid exactly covers the calculated
range.

=cut

{
    my %exp = ( min => 1, nbins => 9, binw => 1.1 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min  => num( $exp{min} ),
            max  => num( $exp{min} + $exp{nbins} * $exp{binw} ),
            binw => array_each( num( $exp{binw}, $tol ) ),
        ),
        "min, nbins, binw",
    );

}

{
    my %exp = ( max => 10.9, nbins => 9, binw => 1.1 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            max  => num( $exp{max} ),
            min  => num( $exp{max} - $exp{nbins} * $exp{binw} ),
            binw => array_each( num( $exp{binw}, $tol ) ),
        ),
        "max, nbins, binw",
    );

}

=pod

=item I<min>, I<soft_max>, I<nbins>

=item I<max>, I<soft_min>, I<nbins>

The extrema are as specified. The grid exactly covers the specified
range.

=cut

{
    my %exp = ( min => 1, soft_max => 10, nbins => 9 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min   => num( $exp{min} ),
            max   => num( $exp{soft_max} ),
            nbins => $exp{nbins},
            binw  => array_each( num( 1, $tol ) ),
        ),
        "min, soft_max, nbins",
    );

}

{
    my %exp = ( soft_min => 1, max => 10, nbins => 9 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min   => num( $exp{soft_min} ),
            max   => num( $exp{max} ),
            nbins => $exp{nbins},
            binw  => array_each( num( 1, $tol ) ),
        ),
        "soft_min, max, nbins",
    );

}

=pod

=item I<min>, I<soft_max>, I<binw>

=item I<max>, I<soft_min>, I<binw>

The hard extremum is as specified. The number of bins is chosen to
minimally cover the specified range.


=cut

{
    my %exp = ( min => 1, soft_max => 10, binw => 1.1 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min  => num( $exp{min} ),
            max  => num( 10.9 ),
            binw => array_each( num( $exp{binw}, $tol ) ),
        ),
        "min, soft_max, binw",
    );

}

{
    my %exp = ( soft_min => 1, max => 10, binw => 1.1 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min  => num( 0.1 ),
            max  => num( $exp{max} ),
            binw => array_each( num( $exp{binw}, $tol ) ),
        ),
        "soft_min, max, binw",
    );

}



=pod

=item I<center>, I<range_width>, I<nbins>

The grid exactly covers the range.

=cut

{
    my %exp = ( center => 0, range_width => 10, nbins => 10 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min => num( -5 ),
            max => num( 5 ),
        ),
        "center, range_width, nbins even",
    );

}


{
    my %exp = ( center => 0, range_width => 11, nbins => 11 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min => num( -5.5 ),
            max => num( 5.5 ),
        ),
        "center, range_width, nbins odd",
    );

}

=pod

=item I<center>, I<range_width>, I<binw>

The bins are aligned so that the center of a bin is at the specified
center; the grid minimally covers the range.


=cut


{
    my %exp = ( center => 0, range_width => 10, binw => 1 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min  => num( -5.5 ),
            max  => num( 5.5 ),
            binw => array_each( num( $exp{binw}, $tol ) ),
        ),
        "center, range_width, binw",
    );

}



=pod

=item I<center>, I<nbins>, I<binw>

The grid exactly covers the range.

=cut

{
    my %exp = ( center => 0, binw => 1, nbins => 10 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min  => num( -5 ),
            max  => num( 5 ),
            binw => array_each( num( $exp{binw}, $tol ) ),
        ),
        'center, binw, nbins even'
    );

}


{
    my %exp = ( center => 0, binw => 1, nbins => 11 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min  => num( -5.5 ),
            max  => num( 5.5 ),
            binw => array_each( num( $exp{binw}, $tol ) ),
        ),
        'center, binw, nbins odd'
    );

}

=pod



=item I<center>, I<soft_min>, I<soft_max>, I<nbins>

The grid is centered on the specified center and the grid minimally
covers the specified range.

=cut

{
    my %exp = ( center => 0, soft_min => -5, soft_max => 3, nbins => 10 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min  => num( -5 ),
            max  => num( 5 ),
            binw => array_each( num( 1, $tol ) ),
        ),
        'center, soft_min, soft_max, nbins even',
    );


}


{

    my %exp = ( center => 0, soft_min => -3, soft_max => 5, nbins => 11 );

    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min  => num( -5 ),
            max  => num( +5 ),
            binw => array_each( num( 10 / 11, $tol ) ),
        ),
        'center, soft_min, soft_max, nbins odd'
    );

}

=pod


=item I<center>, I<soft_min>, I<soft_max>, I<binw>

The grid is centered on the specified center and the grid minimally
covers the specified range.

=cut


{
    my %exp = ( center => 0, soft_min => -5.5, soft_max => 2, binw => 1 );
    my $grid = new( %exp );

    cmp_deeply(
        $grid,
        methods(
            min   => num( -5.5 ),
            max   => num( 5.5 ),
            nbins => 11,
            binw  => array_each( num( 1, $tol ) ),
        ),
        "center, soft_min, soft_max, binw"
    );

}



=pod


=item I<soft_min>, I<soft_max>, I<nbins>, I<binw>

The bins are centered in the middle of the specified range, the grid
extent is determined from I<nbins> and I<binw>.


=cut

{
    my %exp = ( soft_min => -5.5, soft_max => 2, binw => 1, nbins => 11 );
    my $grid = new( %exp );

    my $mid = ( $exp{soft_min} + $exp{soft_max} ) / 2;

    cmp_deeply(
        $grid,
        methods(
            min   => num( $mid - $exp{nbins} / 2 * $exp{binw} ),
            max   => num( $mid + $exp{nbins} / 2 * $exp{binw} ),
            nbins => $exp{nbins},
            binw  => array_each( num( $exp{binw}, $tol ) ),
        ),
        "soft_min, soft_max, binw, nbins"
    );

}

like(
    exception {
        Math::Histo::Grid::Linear->new(
            max   => 1,
            min   => 0,
            nbins => 10,
            binw  => 3
          )
    },
    qr/over- or under-specified/,
    "overspecified"
);

# check all underspecified combinations
{
    my %args = ( max => 1, min => 0, nbins => 10, binw => 3 );
    my $s = Set::Partition->new(
        list      => [qw( max min nbins binw )],
        partition => [2] );

    like(
        exception {
            Math::Histo::Grid::Linear->new( map { $_ => $args{$_} }
                  @{ $_->[0] } )
        },
	qr/over- or under-specified/,
        join( ' ', 'underspecified: ', @{ $_->[0] } ),
    ) while $_ = $s->next;
}


done_testing;

